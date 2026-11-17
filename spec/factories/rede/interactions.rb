FactoryBot.define do
  factory :rede_interaction, class: 'Rede::Interaction' do
    account
    project { association :rede_project, account: account }
    contact { association :contact, account: account }
    author_user { association :user, account: account }
    kind { :call }
    answered { true }
    summary { 'Falamos sobre a agenda' }
    occurred_at { 1.hour.ago }

    before(:create) do |interaction|
      Rede::Participation.find_or_create_by!(account: interaction.account, contact: interaction.contact, project: interaction.project)
    end

    trait :note do
      kind { :note }
      answered { nil }
    end
  end
end
