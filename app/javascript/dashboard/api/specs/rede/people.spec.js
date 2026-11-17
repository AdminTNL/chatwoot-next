import api from '../../rede/people';
import ApiClient from '../../ApiClient';

describe('#RedePeopleAPI', () => {
  it('creates correct instance', () => {
    expect(api).toBeInstanceOf(ApiClient);
    expect(api.url).toBe('/api/v1/rede/people');
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
      api.get({ project_ids: [1, 2], page: 2 });
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/rede/people', {
        params: { project_ids: [1, 2], page: 2 },
      });
    });

    it('#filters gets the filter options', () => {
      api.filters();
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/rede/people/filters');
    });

    it('#show gets the profile', () => {
      api.show(9);
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/rede/people/9');
    });

    it('#timeline gets the history with params', () => {
      api.timeline(9, { before: 'abc', limit: 20 });
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/rede/people/9/timeline',
        { params: { before: 'abc', limit: 20 } }
      );
    });
  });
});
