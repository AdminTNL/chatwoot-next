import { setActivePinia, createPinia } from 'pinia';
import ApiTokensAPI from 'dashboard/api/rede/apiTokens';
import { useRedeApiTokensStore } from './apiTokens';

vi.mock('dashboard/api/rede/apiTokens', () => ({
  default: {
    get: vi.fn(),
    create: vi.fn(),
    revoke: vi.fn(),
  },
}));

vi.mock('dashboard/store/utils/api', () => ({
  throwErrorMessage: vi.fn(error => {
    throw error;
  }),
}));

const listed = {
  id: 1,
  name: 'Abib',
  token_prefix: 'abcd',
  revoked_at: null,
  last_used_at: null,
};

const created = {
  id: 2,
  name: 'Novo',
  token_prefix: 'wxyz',
  token: 'segredo-123',
};

describe('rede api tokens store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it('get loads and camelizes the tokens', async () => {
    ApiTokensAPI.get.mockResolvedValue({ data: [listed] });
    const store = useRedeApiTokensStore();
    await store.get();
    expect(store.records[0].tokenPrefix).toBe('abcd');
    expect(store.uiFlags.fetchingList).toBe(false);
  });

  it('create keeps the plain value only in lastCreatedToken', async () => {
    ApiTokensAPI.create.mockResolvedValue({ data: created });
    const store = useRedeApiTokensStore();
    await store.create({ name: 'Novo' });
    expect(ApiTokensAPI.create).toHaveBeenCalledWith({ name: 'Novo' });
    expect(store.lastCreatedToken).toBe('segredo-123');
    expect(store.records).toHaveLength(1);
    expect(JSON.stringify(store.records)).not.toContain('segredo-123');
  });

  it('clearLastCreated wipes the value', async () => {
    ApiTokensAPI.create.mockResolvedValue({ data: created });
    const store = useRedeApiTokensStore();
    await store.create({ name: 'Novo' });
    store.clearLastCreated();
    expect(store.lastCreatedToken).toBeNull();
    expect(JSON.stringify(store.$state)).not.toContain('segredo-123');
  });

  it('revoke replaces the record', async () => {
    ApiTokensAPI.get.mockResolvedValue({ data: [listed] });
    ApiTokensAPI.revoke.mockResolvedValue({
      data: { ...listed, revoked_at: '2026-11-16T10:00:00Z' },
    });
    const store = useRedeApiTokensStore();
    await store.get();
    await store.revoke(1);
    expect(ApiTokensAPI.revoke).toHaveBeenCalledWith(1);
    expect(store.records[0].revokedAt).toBe('2026-11-16T10:00:00Z');
  });
});
