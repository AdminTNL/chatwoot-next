FactoryBot.define do
  factory :rede_role, class: 'Rede::Role' do
    account
    sequence(:key) { |n| "papel_#{n}" }
    sequence(:name) { |n| "Papel #{n}" }
  end
end
