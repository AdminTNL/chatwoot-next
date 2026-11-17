import camelcaseKeys from 'camelcase-keys';
import OverviewAPI from 'dashboard/api/rede/overview';
import { createStore } from 'dashboard/store/storeFactory';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export const useRedeOverviewStore = createStore({
  name: 'rede-overview',
  type: 'pinia',
  API: OverviewAPI,
  state: () => ({
    overview: {},
  }),

  actions: () => ({
    async get(projectId) {
      this.setUIFlag({ fetchingItem: true });
      try {
        const { data } = await OverviewAPI.get(
          projectId ? { project_id: projectId } : {}
        );
        // `filters` fica em snake_case: são os parâmetros prontos da lista de pessoas.
        this.overview = camelcaseKeys(data || {}, {
          deep: true,
          stopPaths: ['filters'],
        });
        return this.overview;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingItem: false });
      }
    },

    reset() {
      this.overview = {};
      this.uiFlags = { ...this.uiFlags, fetchingItem: false };
    },
  }),
});
