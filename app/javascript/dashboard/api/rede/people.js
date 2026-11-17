/* global axios */
import ApiClient from '../ApiClient';

class RedePeopleAPI extends ApiClient {
  constructor() {
    super('rede/people', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  filters() {
    return axios.get(`${this.url}/filters`);
  }

  timeline(id, params = {}) {
    return axios.get(`${this.url}/${id}/timeline`, { params });
  }
}

// Só leitura: a pessoa é um contato, editado pelas rotas de contatos.
const api = new RedePeopleAPI();
api.create = undefined;
api.update = undefined;
api.delete = undefined;

export default api;
