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

  before_validation :set_defaults, on: :create
  before_validation :normalize_aliases
  before_validation :generate_pretty_name, on: :create

  validates :name, presence: true
  validates :job_type, presence: true, inclusion: { in: JOB_TYPES }
  validates :token, presence: true, uniqueness: true
  validates :pretty_email, uniqueness: true, allow_blank: true
  validates :user_email, uniqueness: true, allow_blank: true

  validates :pretty_email, format: { with: /\A[a-z0-9_]+\z/ }, allow_blank: true
  validates :user_email, format: { with: /\A[a-z0-9_]+\z/ }, allow_blank: true

  validate :user_email_must_be_unique_across_aliases

  def token_address
    "#{token}@mypva.io"
  end

  def pretty_address
    return if pretty_email.blank?
    "#{pretty_email}@mypva.io"
  end

  def user_address
    return if user_email.blank?
    "#{user_email}@mypva.io"
  end

  def all_inbound_addresses
    [token_address, pretty_address, user_address].compact.uniq
  end

  def user_email_must_be_unique_across_aliases
    return if user_email.blank?

    normalized = normalize_local_part(user_email)

    scope = Job.where.not(id: id)

    if scope.where("LOWER(user_email) = :value OR LOWER(pretty_email) = :value", value: normalized).exists?
      errors.add(:user_email, "is already taken")
    end
  end

  private

  def set_defaults
    self.token ||= generate_unique_token
    self.pretty_email ||= generate_unique_pretty_email if pretty_name.present?
  end

  def normalize_aliases
    self.pretty_email = normalize_local_part(pretty_email) if pretty_email.present?
    self.user_email = normalize_local_part(user_email) if user_email.present?
  end

  def normalize_local_part(value)
    value.to_s.downcase.strip
         .gsub(/\s+/, "_")
         .gsub(/[^a-z0-9_]/, "")
         .squeeze("_")
         .sub(/\A_+/, "")
         .sub(/_+\z/, "")
  end

  def generate_unique_token
    loop do
      value = SecureRandom.urlsafe_base64(12).downcase.delete("-")
      break value unless self.class.exists?(token: value)
    end
  end

  def generate_unique_pretty_email
    base = normalize_local_part(pretty_name)
    candidate = base
    counter = 2

    while self.class.exists?(pretty_email: candidate)
      candidate = "#{base}_#{counter}"
      counter += 1
    end

    candidate
  end

  def generate_pretty_name
  return if pretty_name.present?

  loop do
    first = Faker::Name.first_name
    last  = Faker::Name.last_name

    name  = "#{first} #{last}"
    email = "#{first}_#{last}".downcase

    unless Job.exists?(pretty_email: email)
      self.pretty_name = name
      self.pretty_email = email
      break
    end
  end
end
end