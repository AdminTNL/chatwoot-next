json.id resource.id
json.contact_id resource.contact_id
json.project_id resource.project_id
json.front_id resource.front_id
json.kind resource.kind
json.answered resource.answered
json.summary resource.summary
json.occurred_at resource.occurred_at
json.created_at resource.created_at
json.author do
  json.id resource.author_user&.id
  json.name resource.author_user&.name
end
