json.array! @fronts do |front|
  json.partial! 'api/v1/models/rede/front', formats: [:json], resource: front
end
