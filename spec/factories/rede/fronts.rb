FactoryBot.define do
  factory :rede_front, class: 'Rede::Front' do
    account
    project { association :rede_project, account: account }
    sequence(:name) { |n| "Frente #{n}" }
  end
end
