/* global axios */
import ApiClient from '../ApiClient';

class RedeInteractionsAPI extends ApiClient {
  constructor() {
    super('rede/interactions', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }
}

const api = new RedeInteractionsAPI();
api.show = undefined;
api.delete = undefined;

export default api;
