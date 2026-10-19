import { throwErrorMessage } from 'dashboard/store/utils/api';
import { emitter } from 'shared/helpers/mitt';
import ConversationApi from '../../../../api/inbox/conversation';
import mutationTypes from '../../../mutation-types';

export default {
  markMessagesRead: async ({ commit, state }, data) => {
    const conversation = state?.allConversations?.find(
      chat => chat.id === data.id
    );
    const hadUnread = (conversation?.unread_count ?? 0) > 0;
    try {
      const {
        data: { id, agent_last_seen_at: lastSeen },
      } = await ConversationApi.markMessageRead(data);
      setTimeout(
        () =>
          commit(mutationTypes.UPDATE_MESSAGE_UNREAD_COUNT, { id, lastSeen }),
        4000
      );
      if (hadUnread) emitter.emit('fetch_conversation_stats');
    } catch (error) {
      // Handle error
    }
  },

  markMessagesUnread: async ({ commit }, { id }) => {
    try {
      const {
        data: { agent_last_seen_at: lastSeen, unread_count: unreadCount },
      } = await ConversationApi.markMessagesUnread({ id });
      commit(mutationTypes.UPDATE_MESSAGE_UNREAD_COUNT, {
        id,
        lastSeen,
        unreadCount,
      });
      emitter.emit('fetch_conversation_stats');
    } catch (error) {
      throwErrorMessage(error);
    }
  },
};
