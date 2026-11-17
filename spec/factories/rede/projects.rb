FactoryBot.define do
  factory :rede_project, class: 'Rede::Project' do
    account
    team { association :team, account: account }
    sequence(:name) { |n| "Projeto #{n}" }
    sequence(:slug) { |n| "projeto-#{n}" }
    color { '#1F93FF' }

    # Criar o time já cria o projeto pelo callback; a factory troca esse projeto pelo definido aqui
    # para não violar a unicidade de team_id.
    after(:build) do |project|
      Rede::Project.where(team_id: project.team_id).destroy_all
    end
  end
end
