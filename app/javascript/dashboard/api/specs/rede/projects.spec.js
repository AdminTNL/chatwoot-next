import projectsAPI from '../../rede/projects';
import ApiClient from '../../ApiClient';

describe('#RedeProjectsAPI', () => {
  it('creates correct instance', () => {
    expect(projectsAPI).toBeInstanceOf(ApiClient);
    expect(projectsAPI.url).toBe('/api/v1/rede/projects');
    expect(projectsAPI).toHaveProperty('get');
    expect(projectsAPI).toHaveProperty('create');
    expect(projectsAPI).toHaveProperty('update');
    expect(projectsAPI).toHaveProperty('close');
    expect(projectsAPI).toHaveProperty('reopen');
  });

  it('does not expose a delete call', () => {
    expect(projectsAPI.delete).toBeUndefined();
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

    it('#get lists projects', () => {
      projectsAPI.get();
      expect(axiosMock.get).toHaveBeenCalledWith('/api/v1/rede/projects');
    });

    it('#create posts the project attributes', () => {
      const data = { name: 'Mobiliza PE', color: '#1F93FF', description: 'x' };
      projectsAPI.create(data);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/rede/projects',
        data
      );
    });

    it('#update patches the project', () => {
      projectsAPI.update(3, { name: 'Novo' });
      expect(axiosMock.patch).toHaveBeenCalledWith('/api/v1/rede/projects/3', {
        name: 'Novo',
      });
    });

    it('#close posts to the close member route', () => {
      projectsAPI.close(3);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/rede/projects/3/close'
      );
    });

    it('#reopen posts to the reopen member route', () => {
      projectsAPI.reopen(3);
      expect(axiosMock.post).toHaveBeenCalledWith(
        '/api/v1/rede/projects/3/reopen'
      );
    });
  });
});
