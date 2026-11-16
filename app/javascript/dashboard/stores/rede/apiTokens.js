import camelcaseKeys from 'camelcase-keys';
import ApiTokensAPI from 'dashboard/api/rede/apiTokens';
import { createStore } from 'dashboard/store/storeFactory';
import { throwErrorMessage } from 'dashboard/store/utils/api';

const camelize = data => camelcaseKeys(data || {}, { deep: true });

export const useRedeApiTokensStore = createStore({
  name: 'rede-api-tokens',
  type: 'pinia',
  API: ApiTokensAPI,

  state: () => ({
    // Valor em claro do último token criado. Efêmero: o diálogo chama
    // clearLastCreated ao fechar. Nunca vai para a lista nem para o localStorage.
    lastCreatedToken: null,
  }),

  actions: () => ({
    upsertToken(token) {
      const index = this.records.findIndex(r => r.id === token.id);
      if (index === -1) this.records.push(token);
      else this.records[index] = token;
    },

    async get() {
      this.setUIFlag({ fetchingList: true });
      try {
        const { data } = await ApiTokensAPI.get();
        this.records = camelize(data);
        return this.records;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingList: false });
      }
    },

    async create(attrs) {
      this.setUIFlag({ creatingItem: true });
      try {
        const { data } = await ApiTokensAPI.create(attrs);
        const { token, ...record } = camelize(data);
        this.lastCreatedToken = token;
        this.upsertToken(record);
        return record;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ creatingItem: false });
      }
    },

    async revoke(id) {
      this.setUIFlag({ updatingItem: true });
      try {
        const { data } = await ApiTokensAPI.revoke(id);
        const record = camelize(data);
        this.upsertToken(record);
        return record;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ updatingItem: false });
      }
    },

    clearLastCreated() {
      this.lastCreatedToken = null;
    },
  }),
});
