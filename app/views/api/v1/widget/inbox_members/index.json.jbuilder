json.payload do
  json.array! @agents do |agent|
    json.id agent.id
    json.name agent.available_name
    json.avatar_url agent.avatar_url
    json.availability_status agent.account_users.find_by(account_id: @current_account.id)&.availability_status
  end
end
