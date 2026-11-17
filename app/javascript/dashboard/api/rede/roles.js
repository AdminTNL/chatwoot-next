import ApiClient from '../ApiClient';

class RedeRolesAPI extends ApiClient {
  constructor() {
    super('rede/roles', { accountScoped: true });
  }
}

const api = new RedeRolesAPI();
api.show = undefined;
api.create = undefined;
api.update = undefined;
api.delete = undefined;

export default api;
