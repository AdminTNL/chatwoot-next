json.array! @roles do |role|
  json.partial! 'api/v1/models/rede/role', formats: [:json], resource: role
end
