json.id resource.id
json.project_id resource.project_id
json.contact do
  json.id resource.contact.id
  json.name resource.contact.name
  json.phone_number resource.contact.phone_number
end
json.responsible_user_id resource.responsible_user_id
json.referred_by_contact_id resource.referred_by_contact_id
json.referred_by_text resource.referred_by_text
json.next_step resource.next_step
json.origin resource.origin
json.status resource.status
json.joined_at resource.joined_at
json.assignments resource.assignments.sort_by(&:id) do |assignment|
  json.partial! 'api/v1/models/rede/assignment', formats: [:json], resource: assignment
end
