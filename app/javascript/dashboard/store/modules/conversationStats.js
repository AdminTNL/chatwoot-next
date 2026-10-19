import types from '../mutation-types';
import ConversationApi from '../../api/inbox/conversation';
import { debounce } from '@chatwoot/utils';

const state = {
  allCount: 0,
  unreadCount: 0,
  inProgressCount: 0,
  snoozedCount: 0,
  resolvedCount: 0,
  allConversationsCount: 0,
};

export const getters = {
  getStats: $state => $state,
};

// Incremented by every meta request and every listing (`set`); a response only
// is committed if no newer request/listing started after it.
let statsVersion = 0;

// Filters are read through `getFilters` when the debounce fires, so the request
// always uses the current filters instead of the ones from the last call.
const fetchMetaData = async (commit, getFilters) => {
  statsVersion += 1;
  const requestVersion = statsVersion;
  try {
    const response = await ConversationApi.meta(getFilters());
    const {
      data: { meta },
    } = response;
    if (requestVersion !== statsVersion) return;
    commit(types.SET_CONV_TAB_META, meta);
  } catch (error) {
    // ignore
  }
};

const debouncedFetchMetaData = debounce(fetchMetaData, 1000, false, 5000);
const longDebouncedFetchMetaData = debounce(fetchMetaData, 7500, false, 20000);
const superLongDebouncedFetchMetaData = debounce(
  fetchMetaData,
  15000,
  false,
  30000
);

const metaDebouncers = {
  default: debouncedFetchMetaData,
  long: longDebouncedFetchMetaData,
  superLong: superLongDebouncedFetchMetaData,
};

// allConversationsCount (total of the "Todas" tab) is stable across tabs. It is
// 0 until a request succeeds; under load it stays 0, so treat the unknown case
// as a large account and poll slowest instead of fastest.
export const getMetaDebounceKey = allConversationsCount => {
  if (allConversationsCount > 2000 || allConversationsCount === 0)
    return 'superLong';
  if (allConversationsCount > 100) return 'long';
  return 'default';
};

export const actions = {
  get: ({ commit, state: $state, rootState }) => {
    const getFilters = () => rootState.conversations.conversationFilters;
    metaDebouncers[getMetaDebounceKey($state.allConversationsCount)](
      commit,
      getFilters
    );
  },
  set({ commit }, meta) {
    statsVersion += 1;
    commit(types.SET_CONV_TAB_META, meta);
  },
};

export const mutations = {
  [types.SET_CONV_TAB_META](
    $state,
    {
      all_count: allCount,
      unread_conversations_count: unreadCount,
      in_progress_conversations_count: inProgressCount,
      snoozed_conversations_count: snoozedCount,
      resolved_conversations_count: resolvedCount,
      all_conversations_count: allConversationsCount,
    } = {}
  ) {
    $state.allCount = allCount;
    $state.unreadCount = unreadCount;
    $state.inProgressCount = inProgressCount;
    $state.snoozedCount = snoozedCount;
    $state.resolvedCount = resolvedCount;
    $state.allConversationsCount = allConversationsCount;
    $state.updatedOn = new Date();
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
