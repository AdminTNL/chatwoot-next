class Labels::TaggingWriter
  pattr_initialize [:account!]

  # Applies removed_labels then added_labels to a single taggable record (a Conversation
  # or a Contact), manipulating ActsAsTaggableOn::Tagging rows directly and updating
  # cached_label_list via update_column, so that no callback is triggered on the target
  # (avoiding a propagation loop).
  def apply(record:, added_labels:, removed_labels:)
    record.reload
    current_titles = record.label_list.dup

    if removed_labels.present?
      titles_to_remove = removed_labels & current_titles
      delete_taggings_for(record, titles_to_remove)
      current_titles -= removed_labels
    end

    resolved_titles = Labels::GroupExclusivityResolver.new(account: account)
                                                      .resolve(current_titles: current_titles, added_titles: added_labels)

    delete_taggings_for(record, current_titles - resolved_titles)
    (resolved_titles - current_titles).each { |title| add_tagging_for(record, title) }

    persist_cached_label_list(record, resolved_titles)
  end

  private

  def delete_taggings_for(record, titles)
    return if titles.blank?

    ActsAsTaggableOn::Tagging
      .joins(:tag)
      .where(context: 'labels', taggable: record)
      .where(tags: { name: titles })
      .delete_all
  end

  def add_tagging_for(record, title)
    tag = ActsAsTaggableOn::Tag.find_or_create_by!(name: title)
    ActsAsTaggableOn::Tagging.find_or_create_by!(tag: tag, context: 'labels', taggable: record, tagger: nil)
  end

  def persist_cached_label_list(record, titles)
    # Contact has no cached_label_list column (only Conversation caches acts-as-taggable-on this way);
    # nothing to update in that case, label_list will be computed straight from taggings.
    return unless record.class.column_names.include?('cached_label_list')

    # We only want the acts-as-taggable-on cache effect here, not Conversation/Contact callbacks/events.
    # rubocop:disable Rails/SkipsModelValidations
    record.update_column(:cached_label_list, titles.join("#{ActsAsTaggableOn.delimiter} "))
    # rubocop:enable Rails/SkipsModelValidations
  end
end
