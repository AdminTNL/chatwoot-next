import { setActivePinia, createPinia } from 'pinia';
import QualityAPI from 'dashboard/api/rede/quality';
import { useRedeQualityStore } from './quality';

vi.mock('dashboard/api/rede/quality', () => ({
  default: { get: vi.fn(), dismiss: vi.fn(), merge: vi.fn() },
}));

vi.mock('dashboard/store/utils/api', () => ({
  throwErrorMessage: vi.fn(error => {
    throw error;
  }),
}));

const apiQuality = {
  duplicates: [
    {
      project_id: 1,
      contact_a: { id: 1, name: 'Ana', phone_number: '+5581', city: 'Recife' },
      contact_b: { id: 2, name: 'Ana S', phone_number: '+5581', city: null },
    },
  ],
  incompletes: [{ kind: 'no_phone', contact: { id: 3, name: 'Bia' } }],
  counts: { duplicates: 1, incompletes: 1, resolved_this_month: 4 },
};

describe('rede quality store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    QualityAPI.get.mockResolvedValue({ data: apiQuality });
  });

  it('get loads duplicates, incompletes and counts', async () => {
    const store = useRedeQualityStore();
    await store.get(1);
    expect(QualityAPI.get).toHaveBeenCalledWith(1);
    expect(store.duplicates[0].contactA.phoneNumber).toBe('+5581');
    expect(store.incompletes[0].kind).toBe('no_phone');
    expect(store.counts).toEqual({
      duplicates: 1,
      incompletes: 1,
      resolvedThisMonth: 4,
    });
    expect(store.uiFlags.fetchingList).toBe(false);
  });

  it('get clears the flag and rethrows on error', async () => {
    QualityAPI.get.mockRejectedValue(new Error('403'));
    const store = useRedeQualityStore();
    await expect(store.get(1)).rejects.toThrow('403');
    expect(store.uiFlags.fetchingList).toBe(false);
  });

  it('dismiss posts the pair and reloads the list', async () => {
    QualityAPI.dismiss.mockResolvedValue({
      data: { id: 1, kind: 'dismissed' },
    });
    const store = useRedeQualityStore();
    await store.dismiss({ projectId: 1, contactAId: 1, contactBId: 2 });
    expect(QualityAPI.dismiss).toHaveBeenCalledWith({
      projectId: 1,
      contactAId: 1,
      contactBId: 2,
    });
    expect(QualityAPI.get).toHaveBeenCalledWith(1);
    expect(store.uiFlags.dismissing).toBe(false);
  });

  it('merge posts the pair and reloads the list', async () => {
    QualityAPI.merge.mockResolvedValue({ data: { id: 1, kind: 'merged' } });
    const store = useRedeQualityStore();
    await store.merge({ projectId: 1, baseContactId: 1, mergeeContactId: 2 });
    expect(QualityAPI.merge).toHaveBeenCalledWith({
      projectId: 1,
      baseContactId: 1,
      mergeeContactId: 2,
    });
    expect(QualityAPI.get).toHaveBeenCalledWith(1);
    expect(store.uiFlags.merging).toBe(false);
  });

  it('merge failure rethrows and clears the flag without reloading', async () => {
    QualityAPI.merge.mockRejectedValue(new Error('422'));
    const store = useRedeQualityStore();
    await expect(
      store.merge({ projectId: 1, baseContactId: 1, mergeeContactId: 2 })
    ).rejects.toThrow('422');
    expect(store.uiFlags.merging).toBe(false);
    expect(QualityAPI.get).not.toHaveBeenCalled();
  });

  it('dismiss failure rethrows and clears the flag', async () => {
    QualityAPI.dismiss.mockRejectedValue(new Error('422'));
    const store = useRedeQualityStore();
    await expect(
      store.dismiss({ projectId: 1, contactAId: 1, contactBId: 2 })
    ).rejects.toThrow('422');
    expect(store.uiFlags.dismissing).toBe(false);
  });

  it('reloads after dismiss with the fresh list and counts', async () => {
    QualityAPI.dismiss.mockResolvedValue({ data: { id: 1 } });
    QualityAPI.get.mockResolvedValue({
      data: {
        duplicates: [],
        incompletes: [],
        counts: { duplicates: 0, incompletes: 0, resolved_this_month: 5 },
      },
    });
    const store = useRedeQualityStore();
    await store.dismiss({ projectId: 1, contactAId: 1, contactBId: 2 });
    expect(store.duplicates).toEqual([]);
    expect(store.counts.resolvedThisMonth).toBe(5);
  });

  it('reloads after merge with the fresh list and counts', async () => {
    QualityAPI.merge.mockResolvedValue({ data: { id: 1 } });
    QualityAPI.get.mockResolvedValue({
      data: {
        duplicates: [],
        incompletes: [],
        counts: { duplicates: 0, incompletes: 0, resolved_this_month: 1 },
      },
    });
    const store = useRedeQualityStore();
    await store.merge({ projectId: 1, baseContactId: 1, mergeeContactId: 2 });
    expect(store.duplicates).toEqual([]);
    expect(store.counts.resolvedThisMonth).toBe(1);
  });

  it('reset clears the data', async () => {
    const store = useRedeQualityStore();
    await store.get(1);
    store.reset();
    expect(store.duplicates).toEqual([]);
    expect(store.incompletes).toEqual([]);
    expect(store.counts).toEqual({});
  });
});
