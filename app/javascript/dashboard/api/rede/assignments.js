/* global axios */
import ApiClient from '../ApiClient';

class RedeAssignmentsAPI extends ApiClient {
  constructor() {
    super('rede/participations', { accountScoped: true });
  }

  assignmentsUrl(participationId) {
    return `${this.url}/${participationId}/assignments`;
  }

  create(participationId, data) {
    return axios.post(this.assignmentsUrl(participationId), data);
  }

  update(participationId, id, data) {
    return axios.patch(`${this.assignmentsUrl(participationId)}/${id}`, data);
  }

  close(participationId, id) {
    return axios.post(`${this.assignmentsUrl(participationId)}/${id}/close`);
  }
}

const api = new RedeAssignmentsAPI();
api.get = undefined;
api.show = undefined;
api.delete = undefined;

export default api;
