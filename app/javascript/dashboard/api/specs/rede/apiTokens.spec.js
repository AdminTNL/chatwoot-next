import apiTokensAPI from '../../rede/apiTokens';
import ApiClient from '../../ApiClient';

describe('#RedeApiTokensAPI', () => {
  it('creates correct instance', () => {
    expect(apiTokensAPI).toBeInstanceOf(ApiClient);
    expect(apiTokensAPI.url).toBe('/api/v1/rede/api_tokens');
    expect(apiTokensAPI).toHaveProperty('get');
    expect(apiTokensAPI).toHaveProperty('create');
    expect(apiTokensAPI).toHaveProperty('revoke');
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

    it('#get lists tokens', () => {
      apiTokensAPI.get();
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/rede/api_tokens');
    });

    it('#create posts the token name', () => {
      apiTokensAPI.create({ name: 'Abib' });
      expect(axiosMock.post).toHaveBeenCalledWith('/api/v1/rede/api_tokens', {
        name: 'Abib',
      });
    });

    it('#revoke posts to the revoke member route', () => {
      apiTokensAPI.revoke(4);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/rede/api_tokens/4/revoke'
      );
    });
  });
});
