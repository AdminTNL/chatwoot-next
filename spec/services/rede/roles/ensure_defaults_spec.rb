require 'rails_helper'

RSpec.describe Rede::Roles::EnsureDefaults do
  let(:account) { create(:account) }

  it 'creates the four default roles' do
    described_class.new(account).perform

    expect(account.rede_roles.pluck(:key, :name)).to contain_exactly(
      %w[coordenador Coordenador], ['ponto_focal', 'Ponto focal'], %w[mobilizador Mobilizador], %w[entrevistador Entrevistador]
    )
  end

  it 'is idempotent and keeps edited names' do
    described_class.new(account).perform
    account.rede_roles.find_by(key: 'coordenador').update!(name: 'Coord.')

    expect { described_class.new(account).perform }.not_to change(Rede::Role, :count)
    expect(account.rede_roles.find_by(key: 'coordenador').name).to eq('Coord.')
  end

  it 'runs when a project is created' do
    expect { create(:team, account: account) }.to change { account.rede_roles.count }.from(0).to(4)
  end
end
