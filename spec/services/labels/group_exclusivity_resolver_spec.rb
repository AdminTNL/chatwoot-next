require 'rails_helper'

RSpec.describe Labels::GroupExclusivityResolver do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }

  subject(:resolver) { described_class.new(account: account) }

  it 'adds a label and removes another label from the same group already present' do
    label_group = create(:label_group, account: account, team: team)
    old_label = create(:label, account: account, team: team, label_group: label_group)
    new_label = create(:label, account: account, team: team, label_group: label_group)

    result = resolver.resolve(current_titles: [old_label.title], added_titles: [new_label.title])

    expect(result).to contain_exactly(new_label.title)
  end

  it 'just adds a label without a label_group, leaving everything else untouched' do
    label = create(:label, account: account, team: team)

    result = resolver.resolve(current_titles: ['other'], added_titles: [label.title])

    expect(result).to contain_exactly('other', label.title)
  end

  it 'processes added_titles in order, the later one from the same group winning' do
    label_group = create(:label_group, account: account, team: team)
    first_label = create(:label, account: account, team: team, label_group: label_group)
    second_label = create(:label, account: account, team: team, label_group: label_group)

    result = resolver.resolve(current_titles: [], added_titles: [first_label.title, second_label.title])

    expect(result).to contain_exactly(second_label.title)
  end

  it 'does not raise when an added title has no matching Label record, and still adds it' do
    result = resolver.resolve(current_titles: [], added_titles: ['ghost-label'])

    expect(result).to contain_exactly('ghost-label')
  end

  it 'does not duplicate a title that is already present and is added again' do
    label = create(:label, account: account, team: team)

    result = resolver.resolve(current_titles: [label.title], added_titles: [label.title])

    expect(result).to contain_exactly(label.title)
  end
end
