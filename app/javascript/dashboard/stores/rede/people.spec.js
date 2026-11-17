import { setActivePinia, createPinia } from 'pinia';
import PeopleAPI from 'dashboard/api/rede/people';
import { useRedePeopleStore } from './people';

vi.mock('dashboard/api/rede/people', () => ({
  default: { get: vi.fn(), filters: vi.fn() },
}));

vi.mock('dashboard/store/utils/api', () => ({
  throwErrorMessage: vi.fn(error => {
    throw error;
  }),
}));

const apiRow = {
  row_key: '1-2-3',
  contact: { id: 1, name: 'Ana' },
  project: { id: 2, name: 'Mobiliza' },
  front_pending: false,
  last_contact_at: '2026-11-01T10:00:00Z',
  participation_id: 7,
};

describe('rede people store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it('starts empty', () => {
    const store = useRedePeopleStore();
    expect(store.records).toEqual([]);
    expect(store.filters).toEqual({});
    expect(store.filterOptions).toEqual({ projects: [], responsibles: [] });
    expect(store.uiFlags.fetchingList).toBe(false);
  });

  it('get stores the current filters, rows and meta', async () => {
    PeopleAPI.get.mockResolvedValue({
      data: { payload: [apiRow], meta: { count: 40, page: 2, per_page: 25 } },
    });
    const store = useRedePeopleStore();
    await store.get({ project_ids: [2], page: 2 });
    expect(PeopleAPI.get).toHaveBeenCalledWith({ project_ids: [2], page: 2 });
    expect(store.filters).toEqual({ project_ids: [2], page: 2 });
    expect(store.records[0].participationId).toBe(7);
    expect(store.records[0].frontPending).toBe(false);
    expect(store.meta).toEqual({
      count: 40,
      totalCount: 40,
      page: 2,
      perPage: 25,
    });
    expect(store.uiFlags.fetchingList).toBe(false);
  });

  it('get without params reuses the current filters', async () => {
    PeopleAPI.get.mockResolvedValue({
      data: { payload: [], meta: { count: 0, page: 1, per_page: 25 } },
    });
    const store = useRedePeopleStore();
    store.setFilters({ q: 'ana' });
    await store.get();
    expect(PeopleAPI.get).toHaveBeenCalledWith({ q: 'ana' });
  });

  it('get clears the flag and rethrows on error', async () => {
    PeopleAPI.get.mockRejectedValue(new Error('boom'));
    const store = useRedePeopleStore();
    await expect(store.get({})).rejects.toThrow('boom');
    expect(store.uiFlags.fetchingList).toBe(false);
  });

  it('getFilterOptions loads projects and responsibles', async () => {
    PeopleAPI.filters.mockResolvedValue({
      data: {
        projects: [
          {
            id: 1,
            name: 'P',
            fronts: [{ id: 5, name: 'Campo', status: 'active' }],
          },
        ],
        responsibles: [{ id: 9, name: 'Bia' }],
      },
    });
    const store = useRedePeopleStore();
    await store.getFilterOptions();
    expect(store.filterOptions.projects[0].fronts[0].name).toBe('Campo');
    expect(store.filterOptions.responsibles).toEqual([{ id: 9, name: 'Bia' }]);
    expect(store.uiFlags.fetchingFilters).toBe(false);
  });

  it('getFilterOptions clears the flag and rethrows on error', async () => {
    PeopleAPI.filters.mockRejectedValue(new Error('nope'));
    const store = useRedePeopleStore();
    await expect(store.getFilterOptions()).rejects.toThrow('nope');
    expect(store.uiFlags.fetchingFilters).toBe(false);
  });

  it('reset clears everything', async () => {
    PeopleAPI.get.mockResolvedValue({
      data: { payload: [apiRow], meta: { count: 1, page: 1, per_page: 25 } },
    });
    const store = useRedePeopleStore();
    await store.get({ q: 'a' });
    store.reset();
    expect(store.records).toEqual([]);
    expect(store.filters).toEqual({});
    expect(store.meta).toEqual({});
  });
});
