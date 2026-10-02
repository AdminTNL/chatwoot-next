import {
  filterDuplicateSourceMessages,
  getLastMessage,
  getReadMessages,
  getUnreadMessages,
} from '../conversationHelper';
import {
  conversationData,
  lastMessageData,
  readMessagesData,
  unReadMessagesData,
} from './fixtures/conversationFixtures';

describe('conversationHelper', () => {
  describe('#filterDuplicateSourceMessages', () => {
    it('returns messages without duplicate source_id and all messages without source_id', () => {
      const input = [
        { source_id: null, id: 1 },
        { source_id: '', id: 2 },
        { id: 3 },
        { source_id: 'wa_1', id: 4 },
        { source_id: 'wa_1', id: 5 },
        { source_id: 'wa_1', id: 6 },
        { source_id: 'wa_2', id: 7 },
        { source_id: 'wa_2', id: 8 },
        { source_id: 'wa_3', id: 9 },
      ];
      const expected = [
        { source_id: null, id: 1 },
        { source_id: '', id: 2 },
        { id: 3 },
        { source_id: 'wa_1', id: 4 },
        { source_id: 'wa_2', id: 7 },
        { source_id: 'wa_3', id: 9 },
      ];
      expect(filterDuplicateSourceMessages(input)).toEqual(expected);
    });
  });

  describe('#readMessages', () => {
    it('should return read messages if conversation is passed', () => {
      expect(
        getReadMessages(
          conversationData.messages,
          conversationData.agent_last_seen_at
        )
      ).toEqual(readMessagesData);
    });
  });

  describe('#unReadMessages', () => {
    it('should return unread messages if conversation is passed', () => {
      expect(
        getUnreadMessages(
          conversationData.messages,
          conversationData.agent_last_seen_at
        )
      ).toEqual(unReadMessagesData);
    });
  });

  describe('#lastMessage', () => {
    it("should return last activity message if both api and store doesn't have other messages", () => {
      const testConversation = {
        messages: [conversationData.messages[0]],
        last_non_activity_message: null,
      };
      expect(getLastMessage(testConversation)).toEqual(
        testConversation.messages[0]
      );
    });

    it('should return message from store if store has latest message', () => {
      const testConversation = {
        messages: [],
        last_non_activity_message: lastMessageData,
      };
      expect(getLastMessage(testConversation)).toEqual(lastMessageData);
    });

    it('should return last non activity message from store if api value is empty', () => {
      const testConversation = {
        messages: [conversationData.messages[0], conversationData.messages[1]],
        last_non_activity_message: null,
      };
      expect(getLastMessage(testConversation)).toEqual(
        testConversation.messages[1]
      );
    });

    it("should return last non activity message from store if store doesn't have any messages", () => {
      const testConversation = {
        messages: [conversationData.messages[1], conversationData.messages[2]],
        last_non_activity_message: conversationData.messages[0],
      };
      expect(getLastMessage(testConversation)).toEqual(
        testConversation.messages[1]
      );
    });

    describe('public message priority', () => {
      const msg = (id, extra = {}) => ({
        id,
        message_type: 1,
        private: false,
        created_at: id,
        content: `m${id}`,
        ...extra,
      });

      it('returns the public message over a more recent private one', () => {
        const pub = msg(1);
        const priv = msg(2, { private: true });
        expect(
          getLastMessage({
            messages: [pub, priv],
            last_non_activity_message: null,
          })
        ).toEqual(pub);
      });

      it('treats a message with ai_suggestion_id as non public', () => {
        const pub = msg(1);
        const suggestion = msg(2, {
          content_attributes: { ai_suggestion_id: 'x' },
        });
        expect(
          getLastMessage({
            messages: [pub, suggestion],
            last_non_activity_message: null,
          })
        ).toEqual(pub);
      });

      it('falls back to the private message from API when store is empty', () => {
        const priv = msg(2, { private: true });
        expect(
          getLastMessage({ messages: [], last_non_activity_message: priv })
        ).toEqual(priv);
      });

      it('returns the public message from API over a private one in store', () => {
        const pub = msg(1);
        const priv = msg(2, { private: true });
        expect(
          getLastMessage({ messages: [priv], last_non_activity_message: pub })
        ).toEqual(pub);
      });

      it('returns the private message over an activity when no public exists', () => {
        const activity = msg(1, { message_type: 2 });
        const priv = msg(2, { private: true });
        expect(
          getLastMessage({
            messages: [activity, priv],
            last_non_activity_message: null,
          })
        ).toEqual(priv);
      });

      it('returns the activity when it is the only message', () => {
        const activity = msg(1, { message_type: 2 });
        expect(
          getLastMessage({
            messages: [activity],
            last_non_activity_message: null,
          })
        ).toEqual(activity);
      });
    });
  });
});
