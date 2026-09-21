import ApiClient from './ApiClient';

class LabelGroupsAPI extends ApiClient {
  constructor() {
    super('label_groups', { accountScoped: true });
  }
}

export default new LabelGroupsAPI();
