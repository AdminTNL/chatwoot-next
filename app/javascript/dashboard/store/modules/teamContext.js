export const SET_SELECTED_TEAM_ID = 'SET_SELECTED_TEAM_ID';

export const state = {
  selectedTeamId: null,
};

export const getters = {
  getSelectedTeamId: $state => $state.selectedTeamId,
};

export const actions = {
  setSelectedTeam({ commit }, teamId) {
    const id = Number(teamId);
    commit(SET_SELECTED_TEAM_ID, Number.isNaN(id) || !id ? null : id);
  },
  clearSelectedTeam({ commit }) {
    commit(SET_SELECTED_TEAM_ID, null);
  },
};

export const mutations = {
  [SET_SELECTED_TEAM_ID]($state, teamId) {
    $state.selectedTeamId = teamId;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
