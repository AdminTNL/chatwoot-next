import camelcaseKeys from 'camelcase-keys';
import PeopleAPI from 'dashboard/api/rede/people';
import { createStore } from 'dashboard/store/storeFactory';
import { throwErrorMessage } from 'dashboard/store/utils/api';

const camelize = data =>
  camelcaseKeys(data, {
    deep: true,
    stopPaths: ['contact.custom_attributes', 'contact.additional_attributes'],
  });

const createFilterOptions = () => ({ projects: [], responsibles: [] });

export const useRedePeopleStore = createStore({
  name: 'rede-people',
  type: 'pinia',
  API: PeopleAPI,
  state: () => ({
    filters: {},
    filterOptions: createFilterOptions(),
  }),

  actions: () => ({
    setFilters(filters) {
      this.filters = { ...filters };
    },

    async get(params) {
      if (params) this.setFilters(params);
      this.setUIFlag({ fetchingList: true });
      try {
        const {
          data: { payload, meta },
        } = await PeopleAPI.get(this.filters);
        this.records = (payload || []).map(row => camelize(row));
        this.meta = camelcaseKeys(meta || {});
        this.meta.totalCount = this.meta.count;
        return this.records;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingList: false });
      }
    },

    async getFilterOptions() {
      this.setUIFlag({ fetchingFilters: true });
      try {
        const { data } = await PeopleAPI.filters();
        this.filterOptions = {
          projects: camelcaseKeys(data?.projects || [], { deep: true }),
          responsibles: data?.responsibles || [],
        };
        return this.filterOptions;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingFilters: false });
      }
    },

    reset() {
      this.records = [];
      this.meta = {};
      this.filters = {};
      this.filterOptions = createFilterOptions();
      this.uiFlags = {
        ...this.uiFlags,
        fetchingList: false,
        fetchingFilters: false,
      };
    },
  }),
});
