FactoryBot.define do
  factory :rede_api_token, class: 'Rede::ApiToken' do
    transient do
      plain_value { "rede_#{SecureRandom.alphanumeric(40)}" }
    end

    account
    sequence(:name) { |n| "Token #{n}" }
    token_digest { Digest::SHA256.hexdigest(plain_value) }
    token_prefix { plain_value[0, 8] }
    scopes { ['projects:read'] }
  end
end
