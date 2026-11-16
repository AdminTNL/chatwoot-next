FactoryBot.define do
  factory :rede_participation, class: 'Rede::Participation' do
    account
    contact { association :contact, account: account }
    project { association :rede_project, account: account }
  end
end
