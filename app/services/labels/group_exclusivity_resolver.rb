class Labels::GroupExclusivityResolver
  pattr_initialize [:account!]

  # Given the current list of label titles on a record and the titles that are
  # being added to it (processed in order), returns the final list of titles:
  # for each added title that belongs to a label_group, any other title from
  # that same group already present is dropped before the added title itself
  # is included, so that at most one label per group remains. Titles without a
  # matching Label record, or without a label_group, are just added as-is.
  def resolve(current_titles:, added_titles:)
    current_titles = current_titles.dup

    Array(added_titles).each do |title|
      current_titles = strip_group_conflicts(current_titles, title)
      current_titles << title unless current_titles.include?(title)
    end

    current_titles
  end

  private

  def strip_group_conflicts(current_titles, title)
    label = account.labels.find_by(title: title)
    return current_titles if label&.label_group_id.blank?

    group_titles = ::Label
                   .where(account_id: account.id, label_group_id: label.label_group_id)
                   .where.not(id: label.id)
                   .pluck(:title)

    current_titles - (group_titles & current_titles)
  end
end
