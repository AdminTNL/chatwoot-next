import camelcaseKeys from 'camelcase-keys';
import QualityAPI from 'dashboard/api/rede/quality';
import { createStore } from 'dashboard/store/storeFactory';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export const useRedeQualityStore = createStore({
  name: 'rede-quality',
  type: 'pinia',
  API: QualityAPI,
  state: () => ({
    duplicates: [],
    incompletes: [],
    counts: {},
  }),

  actions: () => ({
    async get(projectId) {
      this.setUIFlag({ fetchingList: true });
      try {
        const { data } = await QualityAPI.get(projectId);
        const quality = camelcaseKeys(data || {}, { deep: true });
        this.duplicates = quality.duplicates || [];
        this.incompletes = quality.incompletes || [];
        this.counts = quality.counts || {};
        return quality;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingList: false });
      }
    },

    // Depois de resolver, recarrega: o mesmo contato pode sair de vários pares.
    async dismiss(attrs) {
      this.setUIFlag({ dismissing: true });
      try {
        const { data } = await QualityAPI.dismiss(attrs);
        await this.get(attrs.projectId);
        return camelcaseKeys(data || {});
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ dismissing: false });
      }
    },

    async merge(attrs) {
      this.setUIFlag({ merging: true });
      try {
        const { data } = await QualityAPI.merge(attrs);
        await this.get(attrs.projectId);
        return camelcaseKeys(data || {});
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ merging: false });
      }
    },

    reset() {
      this.duplicates = [];
      this.incompletes = [];
      this.counts = {};
      this.uiFlags = {
        ...this.uiFlags,
        fetchingList: false,
        dismissing: false,
        merging: false,
      };
    },
  }),
});
