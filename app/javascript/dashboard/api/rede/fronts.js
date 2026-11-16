/* global axios */
import ApiClient from '../ApiClient';

class RedeFrontsAPI extends ApiClient {
  constructor() {
    super('rede/projects', { accountScoped: true });
  }

  frontsUrl(projectId) {
    return `${this.url}/${projectId}/fronts`;
  }

  get(projectId) {
    return axios.get(this.frontsUrl(projectId));
  }

  create(projectId, data) {
    return axios.post(this.frontsUrl(projectId), data);
  }

  update(projectId, id, data) {
    return axios.patch(`${this.frontsUrl(projectId)}/${id}`, data);
  }

  close(projectId, id) {
    return axios.post(`${this.frontsUrl(projectId)}/${id}/close`);
  }

  reopen(projectId, id) {
    return axios.post(`${this.frontsUrl(projectId)}/${id}/reopen`);
  }
}

const api = new RedeFrontsAPI();
api.delete = undefined;
api.show = undefined;

export default api;
