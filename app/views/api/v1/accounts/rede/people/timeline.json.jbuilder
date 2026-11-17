json.payload do
  json.array! @events do |event|
    json.partial! 'api/v1/models/rede/timeline_event', formats: [:json], resource: event
  end
end
json.meta @meta
