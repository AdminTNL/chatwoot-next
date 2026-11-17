import api from '../../rede/assignments';
import ApiClient from '../../ApiClient';

describe('#RedeAssignmentsAPI', () => {
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

    it('#create posts under the participation', () => {
      api.create(4, { front_id: 1, role_id: 2 });
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/rede/participations/4/assignments',
        { front_id: 1, role_id: 2 }
      );
    });

    it('#update patches the assignment', () => {
      api.update(4, 7, { role_id: 3 });
      expect(axiosMock.patch).toHaveBeenCalledWith(
        '/api/v1/rede/participations/4/assignments/7',
        { role_id: 3 }
      );
    });

    it('#close posts to the close route', () => {
      api.close(4, 7);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/rede/participations/4/assignments/7/close'
      );
    });
  });
});
