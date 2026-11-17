FactoryBot.define do
  factory :rede_evaluation, class: 'Rede::Evaluation' do
    account
    project { association :rede_project, account: account }
    contact { association :contact, account: account }
    level { 'morno' }
    evaluated_at { Time.current }

    # A pessoa precisa de participação ativa no projeto (validação do model).
    before(:create) do |evaluation|
      Rede::Participation.find_or_create_by!(account_id: evaluation.account_id, contact_id: evaluation.contact_id,
                                             project_id: evaluation.project_id)
    end
  end
end
