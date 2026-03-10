namespace :inbound_emails do
  desc "Fetch inbound emails from IMAP"
  task fetch: :environment do
    count = InboundEmails::ImapFetcher.new.call!
    puts "InboundEmails fetch processed: #{count}"
  end
end