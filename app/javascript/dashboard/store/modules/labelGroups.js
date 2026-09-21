import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import LabelGroupsAPI from '../../api/labelGroups';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getLabelGroups(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getLabelGroupById: _state => id => {
    return _state.records.find(record => record.id === Number(id)) || {};
  },
};

export const actions = {
  get: async function getLabelGroups({ commit }) {
    commit(types.SET_LABEL_GROUP_UI_FLAG, { isFetching: true });
    try {
      const response = await LabelGroupsAPI.get();
      const sortedLabelGroups = response.data.payload.sort((a, b) =>
        a.name.localeCompare(b.name)
      );
      commit(types.SET_LABEL_GROUPS, sortedLabelGroups);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_LABEL_GROUP_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createLabelGroup({ commit }, labelGroupObj) {
    commit(types.SET_LABEL_GROUP_UI_FLAG, { isCreating: true });
    try {
      const response = await LabelGroupsAPI.create(labelGroupObj);
      commit(types.ADD_LABEL_GROUP, response.data);
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_LABEL_GROUP_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateLabelGroup({ commit }, { id, ...updateObj }) {
    commit(types.SET_LABEL_GROUP_UI_FLAG, { isUpdating: true });
    try {
      const response = await LabelGroupsAPI.update(id, updateObj);
      commit(types.EDIT_LABEL_GROUP, response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_LABEL_GROUP_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteLabelGroup({ commit }, id) {
    commit(types.SET_LABEL_GROUP_UI_FLAG, { isDeleting: true });
    try {
      await LabelGroupsAPI.delete(id);
      commit(types.DELETE_LABEL_GROUP, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_LABEL_GROUP_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_LABEL_GROUP_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_LABEL_GROUPS]: MutationHelpers.set,
  [types.ADD_LABEL_GROUP]: MutationHelpers.create,
  [types.EDIT_LABEL_GROUP]: MutationHelpers.update,
  [types.DELETE_LABEL_GROUP]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
