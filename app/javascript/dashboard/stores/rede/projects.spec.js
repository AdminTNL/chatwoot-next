import { setActivePinia, createPinia } from 'pinia';
import ProjectsAPI from 'dashboard/api/rede/projects';
import FrontsAPI from 'dashboard/api/rede/fronts';
import { useRedeProjectsStore } from './projects';

vi.mock('dashboard/api/rede/projects', () => ({
  default: {
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    close: vi.fn(),
    reopen: vi.fn(),
  },
}));

vi.mock('dashboard/api/rede/fronts', () => ({
  default: {
    create: vi.fn(),
    update: vi.fn(),
    close: vi.fn(),
    reopen: vi.fn(),
  },
}));

vi.mock('dashboard/store/utils/api', () => ({
  throwErrorMessage: vi.fn(error => {
    throw error;
  }),
}));

const apiProject = {
  id: 1,
  slug: 'mobiliza-pe',
  name: 'Mobiliza PE',
  color: '#1F93FF',
  status: 'active',
  team_id: 10,
  members_count: 2,
  inboxes_count: 1,
  fronts: [
    { id: 5, public_id: 'u-1', name: 'Campo', has_temperature: true },
    { id: 6, public_id: 'u-2', name: 'Digital', has_temperature: false },
  ],
};

describe('rede projects store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it('get loads and camelizes the projects', async () => {
    ProjectsAPI.get.mockResolvedValue({ data: [apiProject] });
    const store = useRedeProjectsStore();
    await store.get();
    expect(ProjectsAPI.get).toHaveBeenCalled();
    expect(store.records).toHaveLength(1);
    expect(store.records[0].membersCount).toBe(2);
    expect(store.records[0].teamId).toBe(10);
    expect(store.records[0].fronts[0].publicId).toBe('u-1');
    expect(store.uiFlags.fetchingList).toBe(false);
  });

  it('create sends the attrs and upserts the project', async () => {
    ProjectsAPI.create.mockResolvedValue({ data: apiProject });
    const store = useRedeProjectsStore();
    const project = await store.create({ name: 'Mobiliza PE' });
    expect(ProjectsAPI.create).toHaveBeenCalledWith({ name: 'Mobiliza PE' });
    expect(project.teamId).toBe(10);
    expect(store.records).toHaveLength(1);
  });

  it('create clears the flag and rethrows on 422', async () => {
    const error = new Error('Name has already been taken');
    ProjectsAPI.create.mockRejectedValue(error);
    const store = useRedeProjectsStore();
    await expect(store.create({ name: 'x' })).rejects.toThrow(error.message);
    expect(store.uiFlags.creatingItem).toBe(false);
    expect(store.records).toHaveLength(0);
  });

  it('update replaces the record', async () => {
    ProjectsAPI.get.mockResolvedValue({ data: [apiProject] });
    ProjectsAPI.update.mockResolvedValue({
      data: { ...apiProject, name: 'Mobiliza' },
    });
    const store = useRedeProjectsStore();
    await store.get();
    await store.update({ id: 1, name: 'Mobiliza' });
    expect(ProjectsAPI.update).toHaveBeenCalledWith(1, { name: 'Mobiliza' });
    expect(store.records[0].name).toBe('Mobiliza');
    expect(store.records).toHaveLength(1);
  });

  it('close and reopen update the status', async () => {
    ProjectsAPI.get.mockResolvedValue({ data: [apiProject] });
    ProjectsAPI.close.mockResolvedValue({
      data: { ...apiProject, status: 'closed' },
    });
    ProjectsAPI.reopen.mockResolvedValue({ data: apiProject });
    const store = useRedeProjectsStore();
    await store.get();
    await store.close(1);
    expect(ProjectsAPI.close).toHaveBeenCalledWith(1);
    expect(store.records[0].status).toBe('closed');
    await store.reopen(1);
    expect(ProjectsAPI.reopen).toHaveBeenCalledWith(1);
    expect(store.records[0].status).toBe('active');
  });

  it('delete is blocked', () => {
    const store = useRedeProjectsStore();
    expect(() => store.delete(1)).toThrow('use close');
  });

  describe('fronts', () => {
    const loadStore = async () => {
      ProjectsAPI.get.mockResolvedValue({ data: [apiProject] });
      const store = useRedeProjectsStore();
      await store.get();
      return store;
    };

    it('createFront appends the front to the project', async () => {
      FrontsAPI.create.mockResolvedValue({
        data: { id: 9, public_id: 'u-9', name: 'Radio', has_temperature: true },
      });
      const store = await loadStore();
      await store.createFront(1, { name: 'Radio', has_temperature: true });
      expect(FrontsAPI.create).toHaveBeenCalledWith(1, {
        name: 'Radio',
        has_temperature: true,
      });
      expect(store.records[0].fronts).toHaveLength(3);
      expect(store.records[0].fronts[2].publicId).toBe('u-9');
    });

    it('updateFront replaces the front', async () => {
      FrontsAPI.update.mockResolvedValue({
        data: { id: 5, public_id: 'u-1', name: 'Rua', has_temperature: true },
      });
      const store = await loadStore();
      await store.updateFront(1, 5, { name: 'Rua' });
      expect(FrontsAPI.update).toHaveBeenCalledWith(1, 5, { name: 'Rua' });
      expect(store.records[0].fronts[0].name).toBe('Rua');
      expect(store.records[0].fronts).toHaveLength(2);
    });

    it('closeFront and reopenFront replace the front', async () => {
      FrontsAPI.close.mockResolvedValue({
        data: { id: 6, public_id: 'u-2', name: 'Digital', status: 'closed' },
      });
      FrontsAPI.reopen.mockResolvedValue({
        data: { id: 6, public_id: 'u-2', name: 'Digital', status: 'active' },
      });
      const store = await loadStore();
      await store.closeFront(1, 6);
      expect(FrontsAPI.close).toHaveBeenCalledWith(1, 6);
      expect(store.records[0].fronts[1].status).toBe('closed');
      await store.reopenFront(1, 6);
      expect(FrontsAPI.reopen).toHaveBeenCalledWith(1, 6);
      expect(store.records[0].fronts[1].status).toBe('active');
    });
  });
});
