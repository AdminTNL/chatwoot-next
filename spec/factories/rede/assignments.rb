FactoryBot.define do
  factory :rede_assignment, class: 'Rede::Assignment' do
    account
    participation { association :rede_participation, account: account }
  end
end
