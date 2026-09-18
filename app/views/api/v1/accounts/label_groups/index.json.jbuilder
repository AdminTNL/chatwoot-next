json.payload do
  json.array! @label_groups do |label_group|
    json.id label_group.id
    json.name label_group.name
    json.team_id label_group.team_id
    json.account_id label_group.account_id
  end
end
