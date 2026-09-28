import * as types from '../mutation-types';
import ContactAPI from '../../api/contacts';

const state = {
  records: {},
  uiFlags: {
    isFetching: false,
  },
};

export const getters = {
  getUIFlags($state) {
    return $state.uiFlags;
  },
  getTeams: $state => id => {
    return $state.records[Number(id)] || [];
  },
};

export const actions = {
  get: async ({ commit }, contactId) => {
    commit(types.default.SET_CONTACT_TEAMS_UI_FLAG, { isFetching: true });
    try {
      const response = await ContactAPI.getContactableTeams(contactId);
      commit(types.default.SET_CONTACT_TEAMS, {
        id: contactId,
        data: response.data,
      });
    } finally {
      commit(types.default.SET_CONTACT_TEAMS_UI_FLAG, { isFetching: false });
    }
  },
};

export const mutations = {
  [types.default.SET_CONTACT_TEAMS_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
  [types.default.SET_CONTACT_TEAMS]: ($state, { id, data }) => {
    $state.records = {
      ...$state.records,
      [id]: data,
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
