import axios from 'axios';
import { actions, getMetaDebounceKey } from '../../conversationStats';
import * as types from '../../../mutation-types';

const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

const debounceControl = vi.hoisted(() => ({ deferred: false, pending: [] }));

vi.mock('@chatwoot/utils', () => ({
  debounce: vi.fn(fn => {
    return (...args) => {
      if (debounceControl.deferred) {
        debounceControl.pending.push(() => fn(...args));
        return undefined;
      }
      return fn(...args);
    };
  }),
}));

const buildRootState = filters => ({
  conversations: { conversationFilters: filters },
});

const deferred = () => {
  let resolve;
  const promise = new Promise(res => {
    resolve = res;
  });
  return { promise, resolve };
};

describe('#actions', () => {
  beforeEach(() => {
    vi.useFakeTimers(); // Set up fake timers
    commit.mockClear();
    axios.get.mockReset();
    debounceControl.deferred = false;
    debounceControl.pending = [];
  });

  afterEach(() => {
    vi.useRealTimers(); // Reset to real timers after each test
  });

  describe('#get', () => {
    it('sends correct mutations if API is success', async () => {
      axios.get.mockResolvedValue({ data: { meta: { all_count: 1 } } });
      actions.get({
        commit,
        state: { allConversationsCount: 0 },
        rootState: buildRootState({ inboxId: 1, status: 'open' }),
      });

      await vi.runAllTimersAsync();
      await vi.waitFor(() => expect(commit).toHaveBeenCalled());

      expect(commit.mock.calls).toEqual([
        [types.default.SET_CONV_TAB_META, { all_count: 1 }],
      ]);
    });

    it('chama a API com os filtros do store e ignora o payload', async () => {
      axios.get.mockResolvedValue({ data: { meta: {} } });
      actions.get(
        {
          commit,
          state: { allConversationsCount: 0 },
          rootState: buildRootState({ inboxId: 7, status: 'open' }),
        },
        { inboxId: 99, status: 'resolved' }
      );

      await vi.waitFor(() => expect(axios.get).toHaveBeenCalled());

      expect(axios.get.mock.calls[0][1].params).toMatchObject({
        inbox_id: 7,
        status: 'open',
      });
    });

    it('lê os filtros no momento do disparo do debounce', async () => {
      axios.get.mockResolvedValue({ data: { meta: {} } });
      debounceControl.deferred = true;
      const rootState = buildRootState({ inboxId: 1, status: 'open' });

      actions.get({
        commit,
        state: { allConversationsCount: 0 },
        rootState,
      });
      expect(axios.get).not.toHaveBeenCalled();

      rootState.conversations.conversationFilters = {
        inboxId: 2,
        status: 'open',
      };
      debounceControl.pending.forEach(run => run());

      await vi.waitFor(() => expect(axios.get).toHaveBeenCalled());
      expect(axios.get.mock.calls[0][1].params.inbox_id).toBe(2);
    });

    it('descarta a resposta quando um set acontece durante o request', async () => {
      const pending = deferred();
      axios.get.mockReturnValue(pending.promise);

      actions.get({
        commit,
        state: { allConversationsCount: 0 },
        rootState: buildRootState({}),
      });
      actions.set({ commit }, { all_count: 5 });
      pending.resolve({ data: { meta: { all_count: 1 } } });
      await vi.runAllTimersAsync();

      expect(commit.mock.calls).toEqual([
        [types.default.SET_CONV_TAB_META, { all_count: 5 }],
      ]);
    });

    it('descarta a resposta de um get mais antigo quando há um mais novo', async () => {
      const first = deferred();
      const second = deferred();
      axios.get
        .mockReturnValueOnce(first.promise)
        .mockReturnValueOnce(second.promise);
      const context = {
        commit,
        state: { allConversationsCount: 0 },
        rootState: buildRootState({}),
      };

      actions.get(context);
      actions.get(context);
      second.resolve({ data: { meta: { all_count: 2 } } });
      await vi.runAllTimersAsync();
      first.resolve({ data: { meta: { all_count: 1 } } });
      await vi.runAllTimersAsync();

      expect(commit.mock.calls).toEqual([
        [types.default.SET_CONV_TAB_META, { all_count: 2 }],
      ]);
    });

    it('não faz commit se a API falhar', async () => {
      axios.get.mockRejectedValue({ message: 'Incorrect header' });
      actions.get({
        commit,
        state: { allConversationsCount: 0 },
        rootState: buildRootState({}),
      });
      await vi.runAllTimersAsync();
      expect(commit.mock.calls).toEqual([]);
    });
  });

  describe('#set', () => {
    it('sends correct mutations', async () => {
      actions.set({ commit }, { all_count: 2 });
      expect(commit.mock.calls).toEqual([
        [types.default.SET_CONV_TAB_META, { all_count: 2 }],
      ]);
    });
  });

  describe('#getMetaDebounceKey', () => {
    it('escolhe a faixa pelo total de conversas', () => {
      expect(getMetaDebounceKey(0)).toBe('superLong');
      expect(getMetaDebounceKey(50)).toBe('default');
      expect(getMetaDebounceKey(500)).toBe('long');
      expect(getMetaDebounceKey(3000)).toBe('superLong');
    });
  });
});
