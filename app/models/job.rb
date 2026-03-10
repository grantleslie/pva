# app/models/job.rb
class Job < ApplicationRecord
  belongs_to :user
  has_many :inbound_emails, dependent: :destroy

  enum :status, {
    active: "active",
    paused: "paused",
    archived: "archived"
  }, validate: true

  JOB_TYPES = ["email_reader"].freeze
  MY_DOMAIN = "mypva.io".freeze

  before_validation :set_defaults, on: :create
  before_validation :normalize_aliases

  validates :name, presence: true
  validates :job_type, presence: true, inclusion: { in: JOB_TYPES }
  validates :token, presence: true, uniqueness: true
  validates :pretty_email, uniqueness: true, allow_blank: true
  validates :user_email, uniqueness: true, allow_blank: true

  validates :pretty_email, format: { with: /\A[a-z0-9_]+\z/ }, allow_blank: true
  validates :user_email, format: { with: /\A[a-z0-9_]+\z/ }, allow_blank: true

  validate :user_email_must_be_unique_across_aliases
  validate :pretty_email_must_be_unique_across_aliases

  def token_address
    "#{token}@#{MY_DOMAIN}"
  end

  def pretty_address
    return if pretty_email.blank?
    "#{pretty_email}@#{MY_DOMAIN}"
  end

  def user_address
    return if user_email.blank?
    "#{user_email}@#{MY_DOMAIN}"
  end

  def all_inbound_addresses
    [token_address, pretty_address, user_address].compact.uniq
  end

  def self.find_by_incoming_addresses(addresses)
    local_parts = extract_local_parts(addresses)
    return nil if local_parts.empty?

    where(
      "LOWER(token) IN (:parts) OR LOWER(pretty_email) IN (:parts) OR LOWER(user_email) IN (:parts)",
      parts: local_parts
    ).first
  end

  def self.extract_local_parts(addresses)
    Array(addresses)
      .map { |a| a.to_s.downcase.strip }
      .filter_map do |email|
        next if email.blank?

        local, domain = email.split("@", 2)
        next if local.blank?
        next if domain.present? && domain != MY_DOMAIN

        normalize_local_part_static(local)
      end
      .uniq
  end

  def self.normalize_local_part_static(value)
    value.to_s.downcase.strip
         .gsub(/\s+/, "_")
         .gsub(/[^a-z0-9_]/, "")
         .squeeze("_")
         .sub(/\A_+/, "")
         .sub(/_+\z/, "")
  end

  private

  def set_defaults
    self.token ||= generate_unique_token
    generate_pretty_name_if_needed
  end

  def normalize_aliases
    self.pretty_email = normalize_local_part(pretty_email) if pretty_email.present?
    self.user_email = normalize_local_part(user_email) if user_email.present?
  end

  def normalize_local_part(value)
    self.class.normalize_local_part_static(value)
  end

  def generate_unique_token
    loop do
      value = SecureRandom.urlsafe_base64(12).downcase.delete("-")
      break value unless self.class.exists?(token: value)
    end
  end

  def generate_pretty_name_if_needed
    return if pretty_name.present? && pretty_email.present?

    loop do
      first = Faker::Name.first_name
      last  = Faker::Name.last_name

      generated_name = "#{first} #{last}"
      generated_email = normalize_local_part("#{first}_#{last}")

      next if self.class.where.not(id: id)
                        .where("LOWER(pretty_email) = :value OR LOWER(user_email) = :value", value: generated_email)
                        .exists?

      self.pretty_name ||= generated_name
      self.pretty_email ||= generated_email
      break
    end
  end

  def user_email_must_be_unique_across_aliases
    return if user_email.blank?

    normalized = normalize_local_part(user_email)

    if self.class.where.not(id: id)
                 .where("LOWER(user_email) = :value OR LOWER(pretty_email) = :value", value: normalized)
                 .exists?
      errors.add(:user_email, "is already taken")
    end
  end

  def pretty_email_must_be_unique_across_aliases
    return if pretty_email.blank?

    normalized = normalize_local_part(pretty_email)

    if self.class.where.not(id: id)
                 .where("LOWER(pretty_email) = :value OR LOWER(user_email) = :value", value: normalized)
                 .exists?
      errors.add(:pretty_email, "conflicts with an existing email alias")
    end
  end
end