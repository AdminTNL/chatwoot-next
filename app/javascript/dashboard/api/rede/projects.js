/* global axios */
import ApiClient from '../ApiClient';

class RedeProjectsAPI extends ApiClient {
  constructor() {
    super('rede/projects', { accountScoped: true });
  }

  close(id) {
    return axios.post(`${this.url}/${id}/close`);
  }

  reopen(id) {
    return axios.post(`${this.url}/${id}/reopen`);
  }
}

// Projeto nunca é apagado, só encerrado (decisão 3 da 000).
const api = new RedeProjectsAPI();
api.delete = undefined;

export default api;
