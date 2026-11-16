json.array! @projects do |project|
  json.id project.slug
  json.name project.name
  json.status project.status
  json.color project.color
  json.updated_at project.updated_at
  json.fronts project.fronts.sort_by { |front| front.name.downcase } do |front|
    json.id front.public_id
    json.name front.name
    json.status front.status
    json.has_temperature front.has_temperature
    json.updated_at front.updated_at
  end
end
