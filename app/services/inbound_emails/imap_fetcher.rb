# app/services/inbound_emails/imap_fetcher.rb
# frozen_string_literal: true

require "net/imap"
require "mail"
require "stringio"

module InboundEmails
  class ImapFetcher
    def initialize(
      host: ENV["IMAP_HOST"],
      port: (ENV["IMAP_PORT"] || "993").to_i,
      username: ENV["IMAP_USERNAME"],
      password: ENV["IMAP_PASSWORD"],
      mailbox: ENV["IMAP_MAILBOX"] || "INBOX",
      processed_mailbox: ENV["IMAP_PROCESSED_MAILBOX"] # optional
    )
      @host = host
      @port = port
      @username = username
      @password = password
      @mailbox = mailbox
      @processed_mailbox = processed_mailbox
    end

    def call!
      validate_env!

      processed = 0
      imap = Net::IMAP.new(@host, port: @port, ssl: true)

      begin
        imap.login(@username, @password)
        imap.select(@mailbox)

        uids = imap.uid_search(["UNSEEN"])
        return 0 if uids.empty?

        uids.each do |uid|
          begin
            raw = fetch_rfc822(imap, uid)
            msg = Mail.read_from_string(raw)

            message_id = normalized_message_id(msg, uid)

            if ::InboundEmail.exists?(message_id: message_id)
              Rails.logger.info("[InboundEmails::ImapFetcher] Skipping duplicate message_id=#{message_id}")
              mark_seen(imap, uid)
              move_to_processed(imap, uid)
              next
            end

            to_list = extract_addresses(msg.to)
            cc_list = extract_addresses(msg.cc)
            all_recipients = (to_list + cc_list).uniq

            job = ::Job.find_by_incoming_addresses(all_recipients)

            unless job
              Rails.logger.warn(
                "[InboundEmails::ImapFetcher] No matching job for recipients=#{all_recipients.join(', ')} subject=#{msg.subject}"
              )
              mark_seen(imap, uid)
              move_to_processed(imap, uid)
              next
            end

            text_body, html_body = extract_bodies(msg)

            inbound_email = ::InboundEmail.create!(
              job: job,
              message_id: message_id,
              from: extract_addresses(msg.from).join(", "),
              to: to_list.join(", "),
              cc: cc_list.join(", "),
              subject: msg.subject.to_s.strip,
              text_body: text_body,
              html_body: html_body,
              received_at: parsed_received_at(msg),
              headers: safe_headers_hash(msg),
              status: "received"
            )

            attach_attachments!(inbound_email, msg)

            mark_seen(imap, uid)
            move_to_processed(imap, uid)
            processed += 1

            Rails.logger.info(
              "[InboundEmails::ImapFetcher] Saved inbound_email_id=#{inbound_email.id} job_id=#{job.id} subject=#{inbound_email.subject}"
            )

            # Later:
            # InboundEmails::AiProcessJob.perform_later(inbound_email.id)
          rescue => e
            Rails.logger.error(
              "[InboundEmails::ImapFetcher] Error processing uid=#{uid}: #{e.class} - #{e.message}"
            )

            begin
              mark_seen(imap, uid)
            rescue => inner_error
              Rails.logger.error(
                "[InboundEmails::ImapFetcher] Failed to mark seen uid=#{uid}: #{inner_error.class} - #{inner_error.message}"
              )
            end
          end
        end
      ensure
        begin
          imap.logout
        rescue StandardError
        end

        begin
          imap.disconnect
        rescue StandardError
        end
      end

      processed
    end

    private

    def validate_env!
      missing = []
      missing << "IMAP_HOST" if @host.blank?
      missing << "IMAP_USERNAME" if @username.blank?
      missing << "IMAP_PASSWORD" if @password.blank?

      raise "Missing ENV: #{missing.join(', ')}" if missing.any?
    end

    def fetch_rfc822(imap, uid)
      data = imap.uid_fetch(uid, ["RFC822"]).first
      data&.attr&.fetch("RFC822")
    end

    def normalized_message_id(msg, uid)
      raw_message_id = msg.message_id.to_s.strip
      raw_message_id.present? ? raw_message_id : "uid:#{uid}@#{@host}"
    end

    def parsed_received_at(msg)
      msg.date.presence || Time.current
    rescue StandardError
      Time.current
    end

    def mark_seen(imap, uid)
      imap.uid_store(uid, "+FLAGS", [:Seen])
    end

    def move_to_processed(imap, uid)
      return if @processed_mailbox.blank?

      ensure_mailbox_exists(imap, @processed_mailbox)
      imap.uid_copy(uid, @processed_mailbox)
      imap.uid_store(uid, "+FLAGS", [:Deleted])
      imap.expunge
    end

    def ensure_mailbox_exists(imap, name)
      boxes = imap.list("", "*")&.map(&:name) || []
      imap.create(name) unless boxes.include?(name)
    rescue Net::IMAP::NoResponseError
      # ignore if host does not allow mailbox creation
    end

    def extract_addresses(field)
      Array(field).compact.flat_map do |value|
        Mail::AddressList.new(value.to_s).addresses.map(&:address)
      rescue StandardError
        value.to_s.split(/[,\s]+/).map(&:strip)
      end.compact.reject(&:blank?)
    end

    def extract_bodies(msg)
      if msg.multipart?
        text_part = find_text_part(msg)
        html_part = find_html_part(msg)

        [
          text_part&.decoded,
          html_part&.decoded
        ]
      else
        if msg.mime_type.to_s.downcase == "text/html" || msg.content_type.to_s.downcase.include?("text/html")
          [nil, msg.decoded]
        else
          [msg.decoded, nil]
        end
      end
    end

    def find_text_part(msg)
      return msg.text_part if msg.respond_to?(:text_part) && msg.text_part.present?

      Array(msg.parts).find do |part|
        part.mime_type.to_s.downcase.start_with?("text/plain")
      end
    end

    def find_html_part(msg)
      return msg.html_part if msg.respond_to?(:html_part) && msg.html_part.present?

      Array(msg.parts).find do |part|
        part.mime_type.to_s.downcase.start_with?("text/html")
      end
    end

    def attach_attachments!(inbound_email, msg)
      return unless inbound_email.respond_to?(:attachments)
      return if msg.blank?

      Array(msg.attachments).each_with_index do |attachment, idx|
        next if attachment.inline? && !attachment.attachment?

        filename =
          attachment.filename.to_s.presence ||
          "attachment-#{idx + 1}#{infer_extension(attachment.mime_type)}"

        content_type = attachment.mime_type.to_s.presence || "application/octet-stream"
        decoded_body = attachment.decoded

        inbound_email.attachments.attach(
          io: StringIO.new(decoded_body),
          filename: filename,
          content_type: content_type
        )
      rescue => e
        Rails.logger.warn(
          "[InboundEmails::ImapFetcher] Skipping attachment on inbound_email_id=#{inbound_email.id}: #{e.class} - #{e.message}"
        )
      end
    end

    def infer_extension(mime)
      case mime.to_s.downcase
      when "application/pdf" then ".pdf"
      when "image/jpeg" then ".jpg"
      when "image/png" then ".png"
      when "text/plain" then ".txt"
      when "text/html" then ".html"
      when "application/msword" then ".doc"
      when "application/vnd.openxmlformats-officedocument.wordprocessingml.document" then ".docx"
      else
        ""
      end
    end

    def safe_headers_hash(msg)
      keys = %w[
        date
        from
        to
        cc
        subject
        message-id
        reply-to
        delivered-to
        return-path
      ]

      keys.each_with_object({}) do |key, hash|
        hash[key] = msg.header[key]&.to_s
      end
    end
  end
end