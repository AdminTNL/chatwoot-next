class V2::Reports::InboxLabelMatrixBuilder
  include DateRangeHelper

  attr_reader :account, :params

  def initialize(account:, params:)
    @account = account
    @params = params
  end

  def build
    {
      inboxes: filtered_inboxes.map { |inbox| { id: inbox.id, name: inbox.name } },
      labels: filtered_labels.map { |label| { id: label.id, title: label.title } },
      matrix: build_matrix
    }
  end

  private

  def access_scope
    params[:access_scope] || Reports::AccessScope::Null.instance
  end

  def filtered_inboxes
    @filtered_inboxes ||= begin
      inboxes = account.inboxes
      inboxes = inboxes.where(id: access_scope.inbox_ids) unless access_scope.unrestricted?
      inboxes = inboxes.where(id: params[:inbox_ids]) if params[:inbox_ids].present?
      inboxes.order(:name).to_a
    end
  end

  def filtered_labels
    @filtered_labels ||= begin
      labels = account.labels
      labels = labels.where(id: access_scope.label_ids) unless access_scope.unrestricted?
      labels = labels.where(id: params[:label_ids]) if params[:label_ids].present?
      labels.order(:title).to_a
    end
  end

  def conversation_filter
    filter = { account_id: account.id }
    filter[:created_at] = range if range.present?
    inbox_id_filter = accessible_inbox_ids_filter(params[:inbox_ids])
    filter[:inbox_id] = inbox_id_filter unless inbox_id_filter.nil?
    filter
  end

  # Combines the requested `inbox_ids` (if any) with the accessible
  # inbox ids for restricted users, so the raw grouped-count query never
  # touches conversations outside the caller's scope - regardless of
  # what `filtered_inboxes` ends up rendering in the response.
  def accessible_inbox_ids_filter(requested_inbox_ids)
    return requested_inbox_ids if access_scope.unrestricted?
    return access_scope.inbox_ids if requested_inbox_ids.blank?

    Array(requested_inbox_ids).map(&:to_i) & access_scope.inbox_ids
  end

  def fetch_grouped_counts
    label_names = filtered_labels.map(&:title)
    return {} if label_names.empty?

    ActsAsTaggableOn::Tagging
      .joins('INNER JOIN conversations ON taggings.taggable_id = conversations.id')
      .joins('INNER JOIN tags ON taggings.tag_id = tags.id')
      .where(taggable_type: 'Conversation', context: 'labels', conversations: conversation_filter)
      .where(tags: { name: label_names })
      .group('conversations.inbox_id', 'tags.name')
      .count
  end

  def build_matrix
    counts = fetch_grouped_counts
    filtered_inboxes.map do |inbox|
      filtered_labels.map do |label|
        counts[[inbox.id, label.title]] || 0
      end
    end
  end
end
