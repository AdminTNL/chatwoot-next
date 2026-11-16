# == Schema Information
#
# Table name: rede_api_tokens
#
#  id                 :bigint           not null, primary key
#  last_used_at       :datetime
#  name               :string           not null
#  revoked_at         :datetime
#  scopes             :string           default(["projects:read"]), not null, is an Array
#  token_digest       :string           not null
#  token_prefix       :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  created_by_user_id :bigint
#
# Indexes
#
#  index_rede_api_tokens_on_account_id          (account_id)
#  index_rede_api_tokens_on_created_by_user_id  (created_by_user_id)
#  index_rede_api_tokens_on_token_digest        (token_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (created_by_user_id => users.id) ON DELETE => nullify
#
class Rede::ApiToken < ApplicationRecord
  VALUE_PREFIX = 'rede_'.freeze
  SCOPE_PROJECTS_READ = 'projects:read'.freeze
  SCOPES = [SCOPE_PROJECTS_READ].freeze
  LAST_USED_INTERVAL = 1.minute

  belongs_to :account
  belongs_to :created_by_user, class_name: 'User', optional: true

  validates :name, :token_digest, :token_prefix, presence: true
  validates :token_digest, uniqueness: true
  validate :scopes_are_known

  before_validation { self.name = name.strip if name }

  scope :active, -> { where(revoked_at: nil) }

  # Devolve [registro, valor puro]. O valor puro só existe aqui: no banco fica apenas o digest.
  def self.generate!(account:, name:, user:)
    plain = "#{VALUE_PREFIX}#{SecureRandom.alphanumeric(40)}"
    record = create!(account: account, name: name, created_by_user: user, token_digest: digest(plain), token_prefix: plain[0, 8])
    [record, plain]
  end

  def self.digest(plain)
    Digest::SHA256.hexdigest(plain)
  end

  # Busca pelo digest (índice único), então não há comparação do valor puro.
  def self.authenticate(plain)
    return if plain.blank?

    token = active.find_by(token_digest: digest(plain))
    token&.touch_last_used
    token
  end

  def revoke!
    return if revoked?

    update!(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end

  def scope?(scope)
    scopes.include?(scope)
  end

  # No máximo uma escrita por minuto por token, atômica para requisições concorrentes.
  def touch_last_used
    now = Time.current
    updated = self.class.where(id: id).where('last_used_at IS NULL OR last_used_at <= ?', now - LAST_USED_INTERVAL)
                  .update_all(last_used_at: now) # rubocop:disable Rails/SkipsModelValidations
    self.last_used_at = now if updated.positive?
  end

  private

  def scopes_are_known
    errors.add(:scopes, :invalid) unless (scopes - SCOPES).empty?
  end
end
