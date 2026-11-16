json.array! @projects do |project|
  json.partial! 'api/v1/models/rede/project', formats: [:json], resource: project
end
