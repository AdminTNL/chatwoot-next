require 'rails_helper'

# Teste de contrato: protege os comportamentos do chatwoot-next dos quais a integração
# Evolution API (recuperação da lacuna e leitura no celular) depende.
RSpec.describe 'Evolution integration contract', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:channel) { create(:channel_api, account: account) }
  let(:inbox) { channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) do
    # Conversa em outra conta antes, para que o id global avance e difira do display_id desta conta
    create(:conversation, account: create(:account))
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox, status: :open)
  end
  let(:base_url) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}" }

  def unread_ids
    Current.account = account
    ConversationFinder.new(admin, { read_status: 'unread' }).perform[:conversations].map(&:id)
  end

  def in_progress_ids
    Current.account = account
    ConversationFinder.new(admin, { read_status: 'in_progress' }).perform[:conversations].map(&:id)
  end

  def post_last_seen
    post "#{base_url}/update_last_seen", headers: admin_headers, as: :json
  end

  describe 'POST /conversations/:display_id/messages' do
    let(:external_epoch) { 1_761_672_720 }
    let(:incoming_params) do
      { content: 'oi', message_type: 'incoming', source_id: 'WAID:ABC123', external_created_at: external_epoch }
    end

    it 'preserves source_id, stores external_created_at and returns display_id as conversation_id' do
      expect(conversation.display_id).not_to eq(conversation.id)

      post "#{base_url}/messages", params: incoming_params, headers: admin_headers, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['source_id']).to eq('WAID:ABC123')
      expect(body['content_attributes']['external_created_at']).to eq(external_epoch)
      expect(body['conversation_id']).to eq(conversation.display_id)
      expect(body['conversation_id']).not_to eq(conversation.id)
    end

    it 'does not change created_at when external_created_at is sent' do
      conversation
      before_request = Time.current.to_i

      post "#{base_url}/messages", params: incoming_params, headers: admin_headers, as: :json

      expect(response).to have_http_status(:success)
      message = Message.find(response.parsed_body['id'])
      expect(message.created_at.to_i).to be >= before_request
      expect(message.created_at.to_i).not_to eq(external_epoch)
      expect(message.content_attributes['external_created_at']).to eq(external_epoch)
    end

    it 'creates a private outgoing note' do
      post "#{base_url}/messages",
           params: { content: '📥 2 mensagens acima foram recuperadas', message_type: 'outgoing', private: true },
           headers: admin_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['private']).to be(true)
      expect(response.parsed_body['message_type']).to eq(1)
    end
  end

  describe 'POST /conversations/:display_id/update_last_seen' do
    it 'removes the conversation from unread and moves it to in_progress' do
      conversation.update!(agent_last_seen_at: nil)
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming)

      expect(unread_ids).to include(conversation.id)

      post_last_seen

      expect(response).to have_http_status(:success)
      expect(conversation.reload.agent_last_seen_at).not_to be_nil
      expect(unread_ids).not_to include(conversation.id)
      expect(in_progress_ids).to include(conversation.id)
    end

    it 'uses agent_last_seen_at (not assignee_last_seen_at) when assigned to another agent' do
      other_agent = create(:user, account: account, role: :agent)
      conversation.update!(assignee_id: other_agent.id, agent_last_seen_at: nil, assignee_last_seen_at: nil)
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming)

      expect(unread_ids).to include(conversation.id)

      post_last_seen

      expect(response).to have_http_status(:success)
      conversation.reload
      expect(conversation.agent_last_seen_at).not_to be_nil
      expect(conversation.assignee_last_seen_at).to be_nil
      expect(unread_ids).not_to include(conversation.id)
    end

    it 'returns the conversation to unread when a new incoming message arrives after being read' do
      conversation.update!(agent_last_seen_at: nil)
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming)
      post_last_seen
      expect(unread_ids).not_to include(conversation.id)

      travel_to(5.seconds.from_now) do
        create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming)
      end

      expect(unread_ids).to include(conversation.id)
    end

    it 'does not update agent_last_seen_at within the 1 hour throttle when there are no unread messages' do
      last_seen = 10.minutes.ago.change(usec: 0)
      conversation.update!(agent_last_seen_at: last_seen)

      post_last_seen

      expect(response).to have_http_status(:success)
      expect(conversation.reload.agent_last_seen_at).to eq(last_seen)
    end
  end
end
