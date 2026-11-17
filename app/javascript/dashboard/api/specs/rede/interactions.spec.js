import api from '../../rede/interactions';
import ApiClient from '../../ApiClient';

describe('#RedeInteractionsAPI', () => {
  it('creates correct instance', () => {
    expect(api).toBeInstanceOf(ApiClient);
    expect(api.url).toBe('/api/v1/rede/interactions');
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
      api.get({ contact_id: 2 });
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/rede/interactions', {
        params: { contact_id: 2 },
      });
    });

    it('#create posts', () => {
      const data = { project_id: 1, contact_id: 2, kind: 'note' };
      api.create(data);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/rede/interactions',
        data
      );
    });

    it('#update patches', () => {
      api.update(5, { summary: 'x' });
      expect(axiosMock.patch).toHaveBeenCalledWith(
        '/api/v1/rede/interactions/5',
        { summary: 'x' }
      );
    });
  });
});
