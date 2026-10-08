class Api::V1::Widget::InboxMembersController < Api::V1::Widget::BaseController
  skip_before_action :set_contact

  def index
    @agents = @web_widget.inbox.all_member_users.includes(avatar_attachment: :blob)
  end
end
