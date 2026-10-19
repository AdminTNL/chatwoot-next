require 'rails_helper'

RSpec.describe 'Enterprise Inboxes API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  describe 'POST /api/v1/accounts/{account.id}/inboxes' do
    let(:inbox) { create(:inbox, account: account) }

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'creates a voice inbox when administrator' do
        account.enable_features('channel_voice')
        account.save!
        stub_request(:get, %r{api\.twilio\.com/2010-04-01/Accounts/.*/IncomingPhoneNumbers\.json})
          .to_return(status: 200, body: { incoming_phone_numbers: [{ capabilities: { 'voice' => true } }] }.to_json,
                     headers: { 'Content-Type' => 'application/json' })
        allow(Twilio::VoiceWebhookSetupService).to receive(:new).and_return(instance_double(Twilio::VoiceWebhookSetupService,
                                                                                            perform: "AP#{SecureRandom.hex(16)}"))

        post "/api/v1/accounts/#{account.id}/inboxes",
             headers: admin.create_new_auth_token,
             params: { name: 'Voice Inbox',
                       channel: { type: 'voice', phone_number: '+15551234567',
                                  provider_config: { account_sid: "AC#{SecureRandom.hex(16)}",
                                                     auth_token: SecureRandom.hex(16),
                                                     api_key_sid: SecureRandom.hex(8),
                                                     api_key_secret: SecureRandom.hex(16) } } },
             as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Voice Inbox')
        expect(response.body).to include('+15551234567')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/inboxes/:id/set_inbound_calls' do
    before do
      allow(Twilio::VoiceWebhookSetupService).to receive(:new)
        .and_return(instance_double(Twilio::VoiceWebhookSetupService, perform: "AP#{SecureRandom.hex(16)}"))
    end

    context 'when administrator' do
      it 'disables inbound calls on a Twilio voice inbox' do
        channel = create(:channel_twilio_sms, :with_voice, account: account)

        post "/api/v1/accounts/#{account.id}/inboxes/#{channel.inbox.id}/set_inbound_calls",
             headers: admin.create_new_auth_token,
             params: { inbound_calls_enabled: false },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(channel.reload.inbound_calls_enabled?).to be false
      end

      it 'enables inbound calls on a WhatsApp inbox without re-validating provider config' do
        account.enable_features('channel_voice')
        account.save!
        channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                                            validate_provider_config: false, sync_templates: false)
        channel.update!(provider_config: channel.provider_config.merge('calling_enabled' => true, 'inbound_calls_enabled' => false))

        post "/api/v1/accounts/#{account.id}/inboxes/#{channel.inbox.id}/set_inbound_calls",
             headers: admin.create_new_auth_token,
             params: { inbound_calls_enabled: true },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(channel.reload.inbound_calls_enabled?).to be true
      end
    end

    context 'when agent' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'is forbidden' do
        channel = create(:channel_twilio_sms, :with_voice, account: account)

        post "/api/v1/accounts/#{account.id}/inboxes/#{channel.inbox.id}/set_inbound_calls",
             headers: agent.create_new_auth_token,
             params: { inbound_calls_enabled: false },
             as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(channel.reload.inbound_calls_enabled?).to be true
      end
    end
  end
end
