require 'rails_helper'

RSpec.describe Rede::Project do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  # o callback do time já cria o projeto
  let(:project) { team.rede_project }

  describe 'validations' do
    it 'is valid for a team created through the callback' do
      expect(project).to be_valid
    end

    it 'requires name, slug and color' do
      project.assign_attributes(name: '', slug: '', color: '')

      expect(project).not_to be_valid
      expect(project.errors.attribute_names).to include(:name, :slug, :color)
    end

    it 'rejects a color outside #RRGGBB' do
      project.color = 'azul'

      expect(project).not_to be_valid
      expect(project.errors.attribute_names).to include(:color)
    end

    it 'accepts a valid hex color' do
      project.color = '#a1B2c3'

      expect(project).to be_valid
    end

    it 'requires the slug to be unique per account' do
      other = build(:rede_project, account: account, slug: project.slug)

      expect(other).not_to be_valid
      expect(other.errors.attribute_names).to include(:slug)
    end

    it 'allows the same slug in another account' do
      other_account = create(:account)
      other = build(:rede_project, account: other_account, slug: project.slug)

      expect(other).to be_valid
    end

    it 'requires the team to have only one project' do
      other = described_class.new(account: account, team: team, name: 'Outro', slug: 'outro', color: '#1F93FF')

      expect(other).not_to be_valid
      expect(other.errors.attribute_names).to include(:team_id)
    end
  end

  describe 'account destroy' do
    it 'removes the projects together with the account' do
      project

      expect { account.destroy! }.not_to raise_error
      expect(described_class.where(id: project.id)).to be_empty
    end
  end

  describe 'name normalization' do
    it 'strips surrounding whitespace from the name' do
      project.update!(name: '  Mobiliza PA  ')

      expect(project.reload.name).to eq('Mobiliza PA')
    end
  end

  describe 'status' do
    it 'defaults to active' do
      expect(project).to be_active
    end

    it 'can be closed' do
      project.closed!

      expect(project.reload.status).to eq('closed')
    end
  end

  describe 'slug immutability' do
    it 'does not change the slug on update' do
      original = project.slug

      project.update!(slug: 'outro-slug', name: 'Novo nome')

      expect(project.reload.slug).to eq(original)
      expect(project.name).to eq('Novo nome')
    end
  end

  describe 'name sync' do
    it 'updates the team name in lowercase when the project name changes, keeping the project capitalization' do
      project.update!(name: 'Mobiliza PA')

      expect(project.reload.name).to eq('Mobiliza PA')
      expect(team.reload.name).to eq('mobiliza pa')
    end

    it 'rolls back the project name when the team name collides' do
      create(:team, account: account, name: 'ocupado')

      expect { project.update!(name: 'Ocupado') }.to raise_error(ActiveRecord::RecordInvalid)
      expect(project.reload.name).not_to eq('Ocupado')
      expect(team.reload.name).not_to eq('ocupado')
    end

    it 'titleizes the project name when the team name changes elsewhere' do
      team.update!(name: 'novo nome do time')

      expect(project.reload.name).to eq('Novo Nome Do Time')
    end
  end
end
