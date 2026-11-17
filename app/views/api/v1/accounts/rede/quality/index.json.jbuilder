json.duplicates @duplicates do |pair|
  json.project_id pair[:project_id]
  json.contact_a { json.partial! 'api/v1/accounts/rede/quality/contact', contact: pair[:contact_a] }
  json.contact_b { json.partial! 'api/v1/accounts/rede/quality/contact', contact: pair[:contact_b] }
end
json.incompletes @incompletes do |item|
  json.kind item[:kind]
  json.contact { json.partial! 'api/v1/accounts/rede/quality/contact', contact: item[:contact] }
end
json.counts do
  json.duplicates @duplicates.size
  json.incompletes @incompletes.size
  json.resolved_this_month @resolved_this_month
end
