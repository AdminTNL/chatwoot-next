require 'rails_helper'

RSpec.describe 'Conversation Label API', type: :request do
  let(:account) { create(:account) }

  describe 'GET /api/v1/accounts/{account.id}/conversations/<id>/labels' do
    let(:conversation) { create(:conversation, account: account) }

    before do
      conversation.update_labels('label1, label2')
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get api_v1_account_conversation_labels_url(account_id: account.id, conversation_id: conversation.display_id)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user with access to the conversation' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, inbox: conversation.inbox, user: agent)
      end

      it 'returns all the labels for the conversation' do
        get api_v1_account_conversation_labels_url(account_id: account.id, conversation_id: conversation.display_id),
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include('label1')
        expect(response.body).to include('label2')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/<id>/labels' do
    let(:conversation) { create(:conversation, account: account) }

    before do
      conversation.update_labels('label1, label2')
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post api_v1_account_conversation_labels_url(account_id: account.id, conversation_id: conversation.display_id),
             params: { labels: %w[label3 label4] },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user with access to the conversation' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        conversation.update_labels('label1, label2')
        create(:inbox_member, inbox: conversation.inbox, user: agent)
      end

      it 'creates labels for the conversation' do
        post api_v1_account_conversation_labels_url(account_id: account.id, conversation_id: conversation.display_id),
             params: { labels: %w[label3 label4] },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include('label3')
        expect(response.body).to include('label4')
      end

      it 'removes another label from the same label_group on the conversation itself when a new one is added' do
        team = create(:team, account: account)
        label_group = create(:label_group, account: account, team: team)
        old_label = create(:label, account: account, team: team, label_group: label_group)
        new_label = create(:label, account: account, team: team, label_group: label_group)
        conversation.update!(team: team)
        conversation.update_labels([old_label.title])

        post api_v1_account_conversation_labels_url(account_id: account.id, conversation_id: conversation.display_id),
             params: { labels: [new_label.title] },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.label_list).to contain_exactly(new_label.title)
      end
    end
  end
end
