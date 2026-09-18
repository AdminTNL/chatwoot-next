require 'rails_helper'

RSpec.describe LabelGroupPolicy, type: :policy do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:label_group) { create(:label_group, account: account, team: team) }

  let(:administrator) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }

  let(:administrator_context) { { user: administrator, account: account, account_user: account.account_users.find_by(user: administrator) } }
  let(:agent_context) { { user: agent, account: account, account_user: account.account_users.find_by(user: agent) } }

  describe '#index?' do
    it 'grants access to administrators' do
      expect(described_class.new(administrator_context, LabelGroup).index?).to be true
    end

    it 'denies access to agents' do
      expect(described_class.new(agent_context, LabelGroup).index?).to be false
    end
  end

  describe '#show?' do
    it 'grants access to administrators' do
      expect(described_class.new(administrator_context, label_group).show?).to be true
    end

    it 'denies access to agents' do
      expect(described_class.new(agent_context, label_group).show?).to be false
    end
  end

  describe '#create?' do
    it 'grants access to administrators' do
      expect(described_class.new(administrator_context, LabelGroup).create?).to be true
    end

    it 'denies access to agents' do
      expect(described_class.new(agent_context, LabelGroup).create?).to be false
    end
  end

  describe '#update?' do
    it 'grants access to administrators' do
      expect(described_class.new(administrator_context, label_group).update?).to be true
    end

    it 'denies access to agents' do
      expect(described_class.new(agent_context, label_group).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'grants access to administrators' do
      expect(described_class.new(administrator_context, label_group).destroy?).to be true
    end

    it 'denies access to agents' do
      expect(described_class.new(agent_context, label_group).destroy?).to be false
    end
  end
end
