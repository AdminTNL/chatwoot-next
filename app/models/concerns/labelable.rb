module Labelable
  extend ActiveSupport::Concern

  included do
    acts_as_taggable_on :labels
  end

  def update_labels(labels = nil)
    previous_titles = label_list.dup
    # label_list= accepts either an Array or a comma-separated String; assigning it
    # here (instead of parsing `labels` ourselves) lets acts-as-taggable-on normalize
    # it the same way it always has, before we diff against the previous state.
    self.label_list = labels
    new_titles = label_list.dup
    added_titles = new_titles - previous_titles
    kept_titles = new_titles - added_titles

    resolved_titles = Labels::GroupExclusivityResolver.new(account: account)
                                                      .resolve(current_titles: kept_titles, added_titles: added_titles)

    update!(label_list: resolved_titles)
  end

  def add_labels(new_labels = nil)
    return if new_labels.blank?

    new_labels = Array(new_labels) # Make sure new_labels is an array
    combined_labels = labels + new_labels
    update_labels(combined_labels)
  end
end
