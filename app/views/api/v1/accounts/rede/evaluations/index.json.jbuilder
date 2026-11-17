json.array! @evaluations do |evaluation|
  json.partial! 'api/v1/models/rede/evaluation', formats: [:json], resource: evaluation
end
