import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import TagAgents from '../TagAgents.vue';

const i18n = createI18n({
  legacy: false,
  locale: 'en',
  missingWarn: false,
  messages: {
    en: { CONVERSATION: { MENTION: { AGENTS: 'Agents', TEAMS: 'Teams' } } },
  },
});

const defaultTeam = { id: 3, name: 'teste', description: 'Time de teste' };
const assignable = [
  { id: 10, name: 'Ana', email: 'ana@teste.com' },
  { id: 11, name: 'Bruno', email: 'bruno@teste.com' },
];

const buildWrapper = ({
  agents = assignable,
  inbox = { id: 7, team_id: 3 },
  team = defaultTeam,
  searchKey = '',
} = {}) => {
  const store = createStore({
    getters: {
      getSelectedChat: () => ({ id: 1, inbox_id: 7, meta: {} }),
      getCurrentUser: () => ({ id: 1 }),
      getCurrentAccountId: () => 1,
      'inboxAssignableAgents/getAssignableAgents': () => () => agents,
      'inboxes/getInbox': () => () => inbox,
      'teams/getTeamById': () => () => team,
    },
  });
  return mount(TagAgents, {
    props: { searchKey },
    global: {
      plugins: [store, i18n],
      stubs: { Avatar: true },
    },
  });
};

const optionNames = wrapper =>
  wrapper.findAll('[role="option"]').map(o => o.find('h5').text());
const headers = wrapper =>
  wrapper
    .findAll('li')
    .filter(li => !li.find('[role="option"]').exists())
    .map(li => li.text());

describe('TagAgents', () => {
  it('lista só os agentes atribuíveis da inbox e o time da inbox', () => {
    const wrapper = buildWrapper();
    expect(optionNames(wrapper)).toEqual(['Ana', 'Bruno', 'teste']);
    expect(headers(wrapper)).toEqual(['Agents', 'Teams']);
  });

  it('não renderiza a seção Times quando a inbox não tem time', () => {
    const wrapper = buildWrapper({ inbox: { id: 7, team_id: null } });
    expect(optionNames(wrapper)).toEqual(['Ana', 'Bruno']);
    expect(headers(wrapper)).toEqual(['Agents']);
  });

  it('não renderiza o dropdown sem agentes e sem time', () => {
    const wrapper = buildWrapper({
      agents: [],
      inbox: { id: 7, team_id: null },
    });
    expect(wrapper.find('ul').exists()).toBe(false);
  });

  it('ignora o time quando getTeamById devolve objeto vazio', () => {
    const wrapper = buildWrapper({ team: {} });
    expect(optionNames(wrapper)).toEqual(['Ana', 'Bruno']);
    expect(headers(wrapper)).toEqual(['Agents']);
  });

  it('filtra pela busca nas duas seções e remove header de seção vazia', () => {
    const wrapper = buildWrapper({ searchKey: 'ana' });
    expect(optionNames(wrapper)).toEqual(['Ana']);
    expect(headers(wrapper)).toEqual(['Agents']);

    const teamWrapper = buildWrapper({ searchKey: 'tes' });
    expect(optionNames(teamWrapper)).toEqual(['teste']);
    expect(headers(teamWrapper)).toEqual(['Teams']);
  });

  it('não lança erro com registro sem name', () => {
    expect(() =>
      buildWrapper({
        agents: [{ id: 12, email: 'x@teste.com' }, assignable[0]],
        searchKey: 'ana',
      })
    ).not.toThrow();
  });

  it('emite selectAgent com type user ao clicar num agente', async () => {
    const wrapper = buildWrapper();
    await wrapper.findAll('[role="option"]')[0].trigger('click');
    const [payload] = wrapper.emitted('selectAgent')[0];
    expect(payload).toMatchObject({ type: 'user', id: 10 });
  });

  it('emite selectAgent com type team ao clicar no time', async () => {
    const wrapper = buildWrapper();
    await wrapper.findAll('[role="option"]')[2].trigger('click');
    const [payload] = wrapper.emitted('selectAgent')[0];
    expect(payload).toMatchObject({ type: 'team', id: 3 });
  });
});
