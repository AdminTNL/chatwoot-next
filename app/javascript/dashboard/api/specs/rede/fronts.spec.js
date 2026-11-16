import frontsAPI from '../../rede/fronts';
import ApiClient from '../../ApiClient';

describe('#RedeFrontsAPI', () => {
  it('creates correct instance', () => {
    expect(frontsAPI).toBeInstanceOf(ApiClient);
    expect(frontsAPI).toHaveProperty('get');
    expect(frontsAPI).toHaveProperty('create');
    expect(frontsAPI).toHaveProperty('update');
    expect(frontsAPI).toHaveProperty('close');
    expect(frontsAPI).toHaveProperty('reopen');
  });

  it('does not expose delete or show', () => {
    expect(frontsAPI.delete).toBeUndefined();
    expect(frontsAPI.show).toBeUndefined();
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

    it('#get lists the fronts of a project', () => {
      frontsAPI.get(2);
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v1/rede/projects/2/fronts'
      );
    });

    it('#create posts a front under the project', () => {
      frontsAPI.create(2, { name: 'Campo', has_temperature: true });
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/rede/projects/2/fronts',
        { name: 'Campo', has_temperature: true }
      );
    });

    it('#update patches a front', () => {
      frontsAPI.update(2, 7, { name: 'Digital' });
      expect(axiosMock.patch).toHaveBeenCalledWith(
        '/api/v1/rede/projects/2/fronts/7',
        { name: 'Digital' }
      );
    });

    it('#close and #reopen post to the member routes', () => {
      frontsAPI.close(2, 7);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/rede/projects/2/fronts/7/close'
      );
      frontsAPI.reopen(2, 7);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/rede/projects/2/fronts/7/reopen'
      );
    });
  });
});
