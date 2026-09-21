class AiSuggestionGateway
  class RequestError < StandardError
    attr_reader :code, :status

    def initialize(message = nil, code: nil, status: nil)
      super(message)
      @code = code
      @status = status
    end
  end

  def approve(suggestion_id:, operator_id:)
    request(:post, "/admin/approvals/#{suggestion_id}/approve", operator_id: operator_id, body: {}.to_json)
  end

  def reject(suggestion_id:, operator_id:)
    request(:post, "/admin/approvals/#{suggestion_id}/dismiss", operator_id: operator_id, body: {}.to_json)
  end

  def delete_context(inbox_id:, phone:, conversation_id:, operator_id:)
    request(:delete, '/admin/ai-context', operator_id: operator_id,
                                          query: { inbox_id: inbox_id, phone: phone, conversation_id: conversation_id })
  end

  private

  def request(verb, path, operator_id:, body: nil, query: nil)
    raise RequestError, 'AI suggestion service is not configured' if base_url.blank?

    options = {
      headers: {
        'X-Admin-Api-Key' => api_key,
        'X-Operator-Id' => operator_id,
        'Content-Type' => 'application/json'
      },
      timeout: 10
    }
    options[:body] = body unless body.nil?
    options[:query] = query unless query.nil?

    response = HTTParty.public_send(verb, "#{base_url}#{path}", **options)
    raise_request_error(response) unless response.success?

    response.parsed_response
  end

  def raise_request_error(response)
    raise RequestError.new(
      "AI suggestion service returned #{response.code}: #{error_code(response)}",
      code: error_code_string(response),
      status: response.code
    )
  end

  def error_code_string(response)
    body = response.parsed_response
    return nil unless body.is_a?(Hash)

    detail = body['detail']
    value = detail.is_a?(Hash) ? detail['code'] : nil
    value ||= body['code']
    value.is_a?(String) ? value : nil
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
