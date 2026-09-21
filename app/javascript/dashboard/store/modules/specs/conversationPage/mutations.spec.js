import * as types from '../../../mutation-types';
import conversationPageModule, { mutations } from '../../conversationPage';

const initialState = conversationPageModule.state;

describe('#mutations', () => {
  describe('#SET_CURRENT_PAGE', () => {
    it('set current page correctly', () => {
      const state = { currentPage: { unread: 1 } };
      mutations[types.default.SET_CURRENT_PAGE](state, {
        filter: 'unread',
        page: 2,
      });
      expect(state.currentPage).toEqual({
        unread: 2,
      });
    });
  });

  describe('#CLEAR_CONVERSATION_PAGE', () => {
    it('resets the state to initial state', () => {
      const state = {
        currentPage: {
          unread: 1,
          in_progress: 2,
          snoozed: 3,
          resolved: 4,
          all: 5,
        },
        hasEndReached: {
          unread: true,
          in_progress: true,
          snoozed: true,
          resolved: true,
          all: true,
        },
      };
      mutations[types.default.CLEAR_CONVERSATION_PAGE](state);
      expect(state).toEqual({
        currentPage: {
          unread: 0,
          in_progress: 0,
          snoozed: 0,
          resolved: 0,
          all: 0,
          appliedFilters: 0,
        },
        hasEndReached: {
          unread: false,
          in_progress: false,
          snoozed: false,
          resolved: false,
          all: false,
          appliedFilters: false,
        },
      });
    });

    // Regression test for the pagination bug: before the read-status tabs
    // (unread/in_progress/snoozed/resolved/all) replaced the assignee tabs
    // (me/unassigned/all), a brand-new tab key had no entry in `currentPage`,
    // so `getCurrentPageFilter` returned `undefined` and
    // `conversationListPagination` (`currentPage.value + 1`) produced `NaN`
    // as the `page` param sent to the API. Every read-status key must be
    // pre-seeded with `0` so the first "page" is always `0 + 1 = 1`.
    it('seeds every read-status tab key so the first page load never computes NaN', () => {
      const state = { currentPage: {}, hasEndReached: {} };
      mutations[types.default.CLEAR_CONVERSATION_PAGE](state);

      ['unread', 'in_progress', 'snoozed', 'resolved', 'all'].forEach(key => {
        expect(state.currentPage[key]).toBe(0);
        expect(Number.isNaN(state.currentPage[key] + 1)).toBe(false);
      });
    });
  });

  describe('#SET_CONVERSATION_END_REACHED', () => {
    it('set conversation end reached correctly', () => {
      const state = {
        hasEndReached: {
          unread: false,
          in_progress: false,
          snoozed: false,
          resolved: false,
          all: false,
        },
      };
      mutations[types.default.SET_CONVERSATION_END_REACHED](state, {
        filter: 'unread',
      });
      expect(state.hasEndReached).toEqual({
        unread: true,
        in_progress: false,
        snoozed: false,
        resolved: false,
        all: false,
      });
    });

    it('set the 4 other categories to true if "all" has reached its end, since "all" is their exact union', () => {
      const state = {
        hasEndReached: {
          unread: false,
          in_progress: false,
          snoozed: false,
          resolved: false,
          all: false,
        },
      };
      mutations[types.default.SET_CONVERSATION_END_REACHED](state, {
        filter: 'all',
      });
      expect(state.hasEndReached).toEqual({
        unread: true,
        in_progress: true,
        snoozed: true,
        resolved: true,
        all: true,
      });
    });
  });

  describe('module initial state', () => {
    it('initializes currentPage/hasEndReached with the 5 read-status keys', () => {
      expect(initialState.currentPage).toEqual({
        unread: 0,
        in_progress: 0,
        snoozed: 0,
        resolved: 0,
        all: 0,
        appliedFilters: 0,
      });
      expect(initialState.hasEndReached).toEqual({
        unread: false,
        in_progress: false,
        snoozed: false,
        resolved: false,
        all: false,
      });
    });
  });
});
