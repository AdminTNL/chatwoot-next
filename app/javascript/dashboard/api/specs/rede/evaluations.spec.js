import api from '../../rede/evaluations';
import ApiClient from '../../ApiClient';

describe('#RedeEvaluationsAPI', () => {
  it('creates correct instance', () => {
    expect(api).toBeInstanceOf(ApiClient);
    expect(api.url).toBe('/api/v1/rede/evaluations');
  });

  describe('API calls', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      delete: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
      vi.clearAllMocks();
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('#get lists with params', () => {
      api.get({ project_id: 1, contact_id: 2 });
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/rede/evaluations', {
        params: { project_id: 1, contact_id: 2 },
      });
    });

    it('#create posts', () => {
      const data = { project_id: 1, contact_id: 2, level: 'quente' };
      api.create(data);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/rede/evaluations',
        data
      );
    });

    it('has no update or delete', () => {
      expect(api.update).toBeUndefined();
      expect(api.delete).toBeUndefined();
    });
  });
});
