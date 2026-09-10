import * as types from '../mutation-types';

const state = {
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
  },
};

export const getters = {
  getHasEndReached: $state => filter => {
    return $state.hasEndReached[filter];
  },
  getCurrentPageFilter: $state => filter => {
    return $state.currentPage[filter];
  },
  getCurrentPage: $state => {
    return $state.currentPage;
  },
};

export const actions = {
  setCurrentPage({ commit }, { filter, page }) {
    commit(types.default.SET_CURRENT_PAGE, { filter, page });
  },
  setEndReached({ commit }, { filter }) {
    commit(types.default.SET_CONVERSATION_END_REACHED, { filter });
  },
  reset({ commit }) {
    commit(types.default.CLEAR_CONVERSATION_PAGE);
  },
};

export const mutations = {
  [types.default.SET_CURRENT_PAGE]: ($state, { filter, page }) => {
    $state.currentPage = {
      ...$state.currentPage,
      [filter]: page,
    };
  },
  [types.default.SET_CONVERSATION_END_REACHED]: ($state, { filter }) => {
    if (filter === 'all') {
      $state.hasEndReached = {
        ...$state.hasEndReached,
        unread: true,
        in_progress: true,
        snoozed: true,
        resolved: true,
      };
    }
    $state.hasEndReached = {
      ...$state.hasEndReached,
      [filter]: true,
    };
  },
  [types.default.CLEAR_CONVERSATION_PAGE]: $state => {
    $state.currentPage = {
      unread: 0,
      in_progress: 0,
      snoozed: 0,
      resolved: 0,
      all: 0,
      appliedFilters: 0,
    };

    $state.hasEndReached = {
      unread: false,
      in_progress: false,
      snoozed: false,
      resolved: false,
      all: false,
      appliedFilters: false,
    };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
