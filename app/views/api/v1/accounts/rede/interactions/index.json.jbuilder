json.array! @interactions do |interaction|
  json.partial! 'api/v1/models/rede/interaction', formats: [:json], resource: interaction
end
