import types from '../../../mutation-types';
import { mutations } from '../../conversationStats';

describe('#mutations', () => {
  describe('#SET_CONV_TAB_META', () => {
    it('set conversation stats correctly', () => {
      const state = {};
      mutations[types.SET_CONV_TAB_META](state, {
        mine_count: 1,
        unassigned_count: 1,
        all_count: 2,
      });
      expect(state).toEqual({
        mineCount: 1,
        unAssignedCount: 1,
        allCount: 2,
        updatedOn: expect.any(Date),
      });
    });

    it('destructures the 5 read-status counts into their camelCase state keys', () => {
      const state = {};
      mutations[types.SET_CONV_TAB_META](state, {
        mine_count: 1,
        unassigned_count: 1,
        all_count: 2,
        unread_conversations_count: 3,
        in_progress_conversations_count: 4,
        snoozed_conversations_count: 5,
        resolved_conversations_count: 6,
        all_conversations_count: 18,
      });
      expect(state).toEqual({
        mineCount: 1,
        unAssignedCount: 1,
        allCount: 2,
        unreadCount: 3,
        inProgressCount: 4,
        snoozedCount: 5,
        resolvedCount: 6,
        allConversationsCount: 18,
        updatedOn: expect.any(Date),
      });
    });
  });
});
