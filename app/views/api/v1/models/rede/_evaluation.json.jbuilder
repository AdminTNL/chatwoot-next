json.id resource.id
json.contact_id resource.contact_id
json.project_id resource.project_id
json.front_id resource.front_id
json.dimension resource.dimension
json.level resource.level
json.note resource.note
json.evaluated_at resource.evaluated_at
json.author do
  if resource.author_user
    json.id resource.author_user.id
    json.name resource.author_user.name
  else
    json.nil!
  end
end
