import api from '../../rede/quality';
import ApiClient from '../../ApiClient';

describe('#RedeQualityAPI', () => {
  it('creates correct instance', () => {
    expect(api).toBeInstanceOf(ApiClient);
    expect(api.url).toBe('/api/v1/rede/quality');
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

    it('#get lists the issues of a project', () => {
      api.get(3);
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/rede/quality', {
        params: { project_id: 3 },
      });
    });

    it('#dismiss posts the pair', () => {
      api.dismiss({ projectId: 3, contactAId: 1, contactBId: 2 });
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/rede/quality/dismissals',
        { project_id: 3, contact_a_id: 1, contact_b_id: 2 }
      );
    });

    it('#merge posts base and mergee', () => {
      api.merge({ projectId: 3, baseContactId: 1, mergeeContactId: 2 });
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/rede/quality/merges',
        { project_id: 3, base_contact_id: 1, mergee_contact_id: 2 }
      );
    });
  });
});
