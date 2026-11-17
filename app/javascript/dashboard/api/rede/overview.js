/* global axios */
import ApiClient from '../ApiClient';

class RedeOverviewAPI extends ApiClient {
  constructor() {
    super('rede/overview', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new RedeOverviewAPI();
