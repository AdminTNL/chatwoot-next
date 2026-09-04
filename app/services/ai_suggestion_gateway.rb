class AiSuggestionGateway
  class RequestError < StandardError; end

  def approve(suggestion_id:, operator_id:)
    post("/admin/approvals/#{suggestion_id}/approve", operator_id: operator_id)
  end

  def reject(suggestion_id:, operator_id:)
    post("/admin/approvals/#{suggestion_id}/dismiss", operator_id: operator_id)
  end

  private

  def post(path, operator_id:)
    raise RequestError, 'AI suggestion service is not configured' if base_url.blank?

    response = HTTParty.post(
      "#{base_url}#{path}",
      headers: {
        'X-Admin-Api-Key' => api_key,
        'X-Operator-Id' => operator_id,
        'Content-Type' => 'application/json'
      },
      body: {}.to_json,
      timeout: 10
    )

    raise RequestError, "AI suggestion service returned #{response.code}: #{error_code(response)}" unless response.success?

    response.parsed_response
  end

  def error_code(response)
    body = response.parsed_response
    body.is_a?(Hash) ? body.dig('detail', 'code') || body['code'] || body : nil
  end

  def base_url
    GlobalConfigService.load('AI_SUGGESTION_SERVICE_URL', nil)
  end

  def api_key
    GlobalConfigService.load('AI_SUGGESTION_SERVICE_API_KEY', nil)
  end
end
