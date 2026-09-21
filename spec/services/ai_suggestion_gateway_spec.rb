require 'rails_helper'

describe AiSuggestionGateway do
  subject(:gateway) { described_class.new }

  let(:base_url) { 'http://chatbot.test' }
  let(:headers) { { 'X-Admin-Api-Key' => 'secret', 'X-Operator-Id' => '7', 'Content-Type' => 'application/json' } }

  before do
    allow(GlobalConfigService).to receive(:load).with('AI_SUGGESTION_SERVICE_URL', nil).and_return(base_url)
    allow(GlobalConfigService).to receive(:load).with('AI_SUGGESTION_SERVICE_API_KEY', nil).and_return('secret')
  end

  def json_response(status, body)
    { status: status, body: body, headers: { 'Content-Type' => 'application/json' } }
  end

  describe '#approve' do
    it 'posts to the approve endpoint and returns the parsed body' do
      stub_request(:post, "#{base_url}/admin/approvals/5/approve").with(headers: headers)
                                                                  .to_return(json_response(200, { status: 'approved' }.to_json))

      expect(gateway.approve(suggestion_id: 5, operator_id: '7')).to eq('status' => 'approved')
    end

    it 'raises with code and status from detail.code' do
      stub_request(:post, "#{base_url}/admin/approvals/5/approve")
        .to_return(json_response(404, { detail: { code: 'suggestion_not_found' } }.to_json))

      expect { gateway.approve(suggestion_id: 5, operator_id: '7') }.to raise_error(described_class::RequestError) do |error|
        expect(error.code).to eq('suggestion_not_found')
        expect(error.status).to eq(404)
        expect(error.message).to eq('AI suggestion service returned 404: suggestion_not_found')
      end
    end
  end

  describe '#reject' do
    it 'raises with code from a top-level code' do
      stub_request(:post, "#{base_url}/admin/approvals/5/dismiss")
        .to_return(json_response(409, { code: 'suggestion_not_dismissable' }.to_json))

      expect { gateway.reject(suggestion_id: 5, operator_id: '7') }.to raise_error(described_class::RequestError) do |error|
        expect(error.code).to eq('suggestion_not_dismissable')
        expect(error.status).to eq(409)
      end
    end

    it 'has nil code for a non-hash body' do
      stub_request(:post, "#{base_url}/admin/approvals/5/dismiss").to_return(json_response(500, '"oops"'))

      expect { gateway.reject(suggestion_id: 5, operator_id: '7') }.to raise_error(described_class::RequestError) do |error|
        expect(error.code).to be_nil
        expect(error.status).to eq(500)
        expect(error.message).to eq('AI suggestion service returned 500: ')
      end
    end

    it 'has nil code for an empty body' do
      stub_request(:post, "#{base_url}/admin/approvals/5/dismiss").to_return(status: 502, body: '')

      expect { gateway.reject(suggestion_id: 5, operator_id: '7') }.to raise_error(described_class::RequestError) do |error|
        expect(error.code).to be_nil
        expect(error.status).to eq(502)
      end
    end
  end

  describe '#delete_context' do
    it 'sends DELETE with query and headers and returns the parsed hash' do
      stub_request(:delete, "#{base_url}/admin/ai-context")
        .with(query: { inbox_id: '3', phone: '5511999999999', conversation_id: '9' }, headers: headers)
        .to_return(json_response(200, { deleted: 2 }.to_json))

      result = gateway.delete_context(inbox_id: 3, phone: '5511999999999', conversation_id: 9, operator_id: '7')

      expect(result).to eq('deleted' => 2)
    end

    it 'raises RequestError with code on failure' do
      stub_request(:delete, "#{base_url}/admin/ai-context").with(query: hash_including({}))
                                                           .to_return(json_response(422, { detail: { code: 'bad' } }.to_json))

      expect { gateway.delete_context(inbox_id: 3, phone: '1', conversation_id: 9, operator_id: '7') }
        .to raise_error(described_class::RequestError) { |error| expect(error.code).to eq('bad') }
    end

    it 'raises when the service is not configured' do
      allow(GlobalConfigService).to receive(:load).with('AI_SUGGESTION_SERVICE_URL', nil).and_return(nil)

      expect { gateway.delete_context(inbox_id: 3, phone: '1', conversation_id: 9, operator_id: '7') }
        .to raise_error(described_class::RequestError, 'AI suggestion service is not configured')
    end
  end
end
