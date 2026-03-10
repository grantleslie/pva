# app/models/inbound_email.rb
class InboundEmail < ApplicationRecord
  belongs_to :job, optional: true

  has_many_attached :attachments

  validates :message_id, presence: true, uniqueness: true

  STATUS = %w[
    received
    matched
    unmatched
    processed
    ignored
    error
  ]
  def from_addresses
    from.to_s.split(",").map(&:strip)
  end

  def to_addresses
    to.to_s.split(",").map(&:strip)
  end

  def cc_addresses
    cc.to_s.split(",").map(&:strip)
  end
end