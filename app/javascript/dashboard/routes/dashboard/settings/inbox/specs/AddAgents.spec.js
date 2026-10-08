import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import AddAgents from '../AddAgents.vue';

const mockReplace = vi.fn();
const mockAlert = vi.fn();

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { inbox_id: '7' } }),
  useRouter: () => ({ replace: mockReplace }),
}));
vi.mock('dashboard/composables', () => ({
  useAlert: (...args) => mockAlert(...args),
}));

const ComboBoxStub = {
  name: 'ComboBox',
  props: ['options', 'modelValue'],
  emits: ['update:modelValue'],
  template: `<div>
    <button v-for="o in options" :key="o.value" :data-test="'opt-' + o.value" @click="$emit('update:modelValue', o.value)">{{ o.label }}</button>
  </div>`,
};

const i18n = createI18n({
  legacy: false,
  locale: 'en',
  missingWarn: false,
  messages: { en: {} },
});

const buildWrapper = (updateInbox = vi.fn().mockResolvedValue({})) => {
  const store = createStore({
    getters: {
      'teams/getTeams': () => [
        { id: 1, name: 'Time A' },
        { id: 2, name: 'Time B' },
      ],
    },
    actions: {
      'teams/get': () => {},
      'inboxes/updateInbox': updateInbox,
    },
  });
  const wrapper = mount(AddAgents, {
    global: {
      plugins: [store, i18n],
      stubs: {
        ComboBox: ComboBoxStub,
        PageHeader: true,
        NextButton: {
          props: ['label'],
          template: '<button type="submit">{{ label }}</button>',
        },
      },
    },
  });
  return { wrapper, updateInbox };
};

describe('AddAgents (passo Time responsável)', () => {
  beforeEach(() => {
    mockReplace.mockClear();
    mockAlert.mockClear();
  });

  it('lista os times da conta mais a opção sem time', () => {
    const { wrapper } = buildWrapper();
    const values = wrapper
      .findComponent(ComboBoxStub)
      .props('options')
      .map(o => o.value);
    expect(values).toEqual(['none', 1, 2]);
  });

  it('salva o time escolhido e navega para o fim', async () => {
    const { wrapper, updateInbox } = buildWrapper();
    await wrapper.find('[data-test="opt-2"]').trigger('click');
    expect(wrapper.find('[data-testid="no-team-warning"]').exists()).toBe(
      false
    );
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(updateInbox.mock.calls[0][1]).toEqual({ id: '7', team_id: 2 });
    expect(mockReplace).toHaveBeenCalledWith({
      name: 'settings_inbox_finish',
      params: { page: 'new', inbox_id: '7' },
    });
  });

  it('sem time envia team_id null e mostra o aviso', async () => {
    const { wrapper, updateInbox } = buildWrapper();
    await wrapper.find('[data-test="opt-1"]').trigger('click');
    await wrapper.find('[data-test="opt-none"]').trigger('click');
    expect(wrapper.find('[data-testid="no-team-warning"]').exists()).toBe(true);
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(updateInbox.mock.calls[0][1]).toEqual({ id: '7', team_id: null });
  });

  it('erro no salvamento mostra alerta e nao navega', async () => {
    const { wrapper } = buildWrapper(vi.fn().mockRejectedValue(new Error('x')));
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(mockAlert).toHaveBeenCalled();
    expect(mockReplace).not.toHaveBeenCalled();
  });
});
