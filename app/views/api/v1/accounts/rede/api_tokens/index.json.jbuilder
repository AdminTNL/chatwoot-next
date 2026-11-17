json.array! @api_tokens do |api_token|
  json.partial! 'api/v1/models/rede/api_token', formats: [:json], resource: api_token
end
