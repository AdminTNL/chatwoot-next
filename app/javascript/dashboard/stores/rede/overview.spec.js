import { setActivePinia, createPinia } from 'pinia';
import OverviewAPI from 'dashboard/api/rede/overview';
import { useRedeOverviewStore } from './overview';

vi.mock('dashboard/api/rede/overview', () => ({
  default: { get: vi.fn() },
}));

vi.mock('dashboard/store/utils/api', () => ({
  throwErrorMessage: vi.fn(error => {
    throw error;
  }),
}));

const apiOverview = {
  people_count: 10,
  front_participations_count: 8,
  pending_front_count: 2,
  no_contact_7d_count: 4,
  by_temperature: { vapor: 1, quente: 2, morno: 3, frio: 1, none: 3 },
  filters: {
    people: { project_ids: [1] },
    no_contact_7d: { project_ids: [1], no_contact_days: 7 },
    by_temperature: { none: { project_ids: [1], temperatures: ['none'] } },
  },
  recent_changes: [{ kind: 'temperature', occurred_at: '2026-11-01' }],
};

describe('rede overview store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it('get loads the numbers, keeping filters as API params', async () => {
    OverviewAPI.get.mockResolvedValue({ data: apiOverview });
    const store = useRedeOverviewStore();
    await store.get(1);
    expect(OverviewAPI.get).toHaveBeenCalledWith({ project_id: 1 });
    expect(store.overview.peopleCount).toBe(10);
    expect(store.overview.noContact7dCount).toBe(4);
    expect(store.overview.byTemperature.none).toBe(3);
    expect(store.overview.recentChanges[0].occurredAt).toBe('2026-11-01');
    expect(store.overview.filters.no_contact_7d).toEqual({
      project_ids: [1],
      no_contact_days: 7,
    });
    expect(store.overview.filters.by_temperature.none.temperatures).toEqual([
      'none',
    ]);
    expect(store.uiFlags.fetchingItem).toBe(false);
  });

  it('get without project asks for all projects', async () => {
    OverviewAPI.get.mockResolvedValue({ data: apiOverview });
    const store = useRedeOverviewStore();
    await store.get();
    expect(OverviewAPI.get).toHaveBeenCalledWith({});
  });

  it('changing the project fetches again with the new id', async () => {
    OverviewAPI.get.mockResolvedValue({ data: apiOverview });
    const store = useRedeOverviewStore();
    await store.get(1);
    await store.get(2);
    expect(OverviewAPI.get).toHaveBeenNthCalledWith(1, { project_id: 1 });
    expect(OverviewAPI.get).toHaveBeenNthCalledWith(2, { project_id: 2 });
  });

  it('get clears the flag and rethrows on error', async () => {
    OverviewAPI.get.mockRejectedValue(new Error('404'));
    const store = useRedeOverviewStore();
    await expect(store.get(9)).rejects.toThrow('404');
    expect(store.uiFlags.fetchingItem).toBe(false);
  });

  it('reset clears the overview', async () => {
    OverviewAPI.get.mockResolvedValue({ data: apiOverview });
    const store = useRedeOverviewStore();
    await store.get();
    store.reset();
    expect(store.overview).toEqual({});
  });
});
