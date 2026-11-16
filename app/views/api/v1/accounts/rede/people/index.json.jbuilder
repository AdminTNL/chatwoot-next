json.payload do
  json.array! @rows do |row|
    json.partial! 'api/v1/models/rede/person_row', formats: [:json], resource: row
  end
end
json.meta @meta
