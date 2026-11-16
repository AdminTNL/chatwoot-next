json.projects @projects do |project|
  json.id project.id
  json.slug project.slug
  json.name project.name
  json.color project.color
  json.status project.status
  json.fronts project.ordered_fronts do |front|
    json.id front.id
    json.name front.name
    json.status front.status
  end
end
json.responsibles @responsibles do |user|
  json.id user.id
  json.name user.name
end
