import ApiClient from '../ApiClient';

class RedeParticipationsAPI extends ApiClient {
  constructor() {
    super('rede/participations', { accountScoped: true });
  }
}

// Só cria e atualiza: a participação encerra pelo status.
const api = new RedeParticipationsAPI();
api.get = undefined;
api.show = undefined;
api.delete = undefined;

export default api;
