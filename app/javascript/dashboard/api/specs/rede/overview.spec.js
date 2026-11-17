import api from '../../rede/overview';
import ApiClient from '../../ApiClient';

describe('#RedeOverviewAPI', () => {
  it('creates correct instance', () => {
    expect(api).toBeInstanceOf(ApiClient);
    expect(api.url).toBe('/api/v1/rede/overview');
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

    it('#get requests the overview without project', () => {
      api.get();
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/rede/overview', {
        params: {},
      });
    });

    it('#get sends the project id', () => {
      api.get({ project_id: 3 });
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/rede/overview', {
        params: { project_id: 3 },
      });
    });
  });
});
