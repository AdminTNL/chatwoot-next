import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import LiveChatCampaignForm from '../LiveChatCampaignForm.vue';

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('urlpattern-polyfill', () => ({ URLPattern: class {} }));

const ComboBoxStub = {
  name: 'ComboBox',
  props: ['options', 'modelValue'],
  emits: ['update:modelValue'],
  template: '<div />',
};

const i18n = createI18n({
  legacy: false,
  locale: 'en',
  missingWarn: false,
  messages: { en: {} },
});

const members = [{ id: 10, name: 'Maria' }];

const buildWrapper = () => {
  const getTeamMembers = vi.fn();
  const store = createStore({
    getters: {
      'campaigns/getUIFlags': () => ({ isCreating: false }),
      'inboxes/getWebsiteInboxes': () => [
        { id: 1, name: 'Com time', team_id: 5 },
        { id: 2, name: 'Sem time', team_id: null },
      ],
      'teamMembers/getTeamMembers': () => id => (id === 5 ? members : []),
    },
    actions: { 'teamMembers/get': getTeamMembers },
  });
  const wrapper = mount(LiveChatCampaignForm, {
    props: { mode: 'create' },
    global: {
      plugins: [store, i18n],
      stubs: {
        ComboBox: ComboBoxStub,
        Input: true,
        Editor: true,
        Button: true,
      },
    },
  });
  return { wrapper, getTeamMembers };
};

const senderOptions = wrapper =>
  wrapper.findAllComponents(ComboBoxStub)[1].props('options');

describe('LiveChatCampaignForm remetentes', () => {
  it('usa os membros do time da inbox escolhida', async () => {
    const { wrapper, getTeamMembers } = buildWrapper();
    wrapper.findAllComponents(ComboBoxStub)[0].vm.$emit('update:modelValue', 1);
    await flushPromises();
    expect(getTeamMembers).toHaveBeenCalled();
    expect(senderOptions(wrapper).map(o => o.label)).toEqual(['Bot', 'Maria']);
  });

  it('inbox sem time deixa apenas o Bot, sem chamar a API', async () => {
    const { wrapper, getTeamMembers } = buildWrapper();
    wrapper.findAllComponents(ComboBoxStub)[0].vm.$emit('update:modelValue', 2);
    await flushPromises();
    expect(getTeamMembers).not.toHaveBeenCalled();
    expect(senderOptions(wrapper).map(o => o.label)).toEqual(['Bot']);
  });
});
