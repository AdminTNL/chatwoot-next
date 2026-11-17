/* global axios */
import ApiClient from '../ApiClient';

class RedeApiTokensAPI extends ApiClient {
  constructor() {
    super('rede/api_tokens', { accountScoped: true });
  }

  revoke(id) {
    return axios.post(`${this.url}/${id}/revoke`);
  }
}

export default new RedeApiTokensAPI();
