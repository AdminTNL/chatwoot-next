/* global axios */
import ApiClient from '../ApiClient';

class RedeQualityAPI extends ApiClient {
  constructor() {
    super('rede/quality', { accountScoped: true });
  }

  get(projectId) {
    return axios.get(this.url, { params: { project_id: projectId } });
  }

  dismiss({ projectId, contactAId, contactBId }) {
    return axios.post(`${this.url}/dismissals`, {
      project_id: projectId,
      contact_a_id: contactAId,
      contact_b_id: contactBId,
    });
  }

  merge({ projectId, baseContactId, mergeeContactId }) {
    return axios.post(`${this.url}/merges`, {
      project_id: projectId,
      base_contact_id: baseContactId,
      mergee_contact_id: mergeeContactId,
    });
  }
}

export default new RedeQualityAPI();
