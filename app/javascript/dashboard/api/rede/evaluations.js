/* global axios */
import ApiClient from '../ApiClient';

class RedeEvaluationsAPI extends ApiClient {
  constructor() {
    super('rede/evaluations', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }
}

// Avaliação só insere: mudar a temperatura é registrar uma linha nova.
const api = new RedeEvaluationsAPI();
api.show = undefined;
api.update = undefined;
api.delete = undefined;

export default api;
