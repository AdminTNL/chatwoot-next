import api from '../../rede/participations';
import ApiClient from '../../ApiClient';

describe('#RedeParticipationsAPI', () => {
  it('creates correct instance', () => {
    expect(api).toBeInstanceOf(ApiClient);
    expect(api.url).toBe('/api/v1/rede/participations');
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

    it('#create posts', () => {
      const data = { project_id: 1, contact_id: 2 };
      api.create(data);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/rede/participations',
        data
      );
    });

    it('#update patches', () => {
      api.update(4, { next_step: 'x' });
      expect(axiosMock.patch).toHaveBeenCalledWith(
        '/api/v1/rede/participations/4',
        { next_step: 'x' }
      );
    });

    it('has no delete', () => {
      expect(api.delete).toBeUndefined();
    });
  });
});
