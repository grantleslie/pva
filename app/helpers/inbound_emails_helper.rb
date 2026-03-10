module InboundEmailsHelper
  def inbound_preview(email)
    body = email.text_body.presence || ActionView::Base.full_sanitizer.sanitize(email.html_body.to_s)
    truncate(body, length: 120)
  end
end