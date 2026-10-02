import { reactive } from 'vue';
import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { useRoute } from 'vue-router';
import ContactLabels from '../ContactLabels.vue';
import LabelItem from 'dashboard/components-next/label/LabelItem.vue';

vi.mock('vue-router');

// AddLabel.vue pulls in DropdownMenu and its own import graph, unrelated to
// what this spec exercises. Stub it with buttons that emit the same
// `update-label` event AddLabel emits when a menu item is clicked.
vi.mock('dashboard/components-next/label/AddLabel.vue', () => ({
  default: {
    name: 'AddLabel',
    props: ['labelMenuItems'],
    emits: ['updateLabel'],
    template: `<div class="add-label-stub">
      <button class="add-first" @click="$emit('updateLabel', { value: labelMenuItems[0]?.value })">add label</button>
      <button v-for="item in labelMenuItems" :key="item.value" :data-test="'item-' + item.value" @click="$emit('updateLabel', { value: item.value })">{{ item.label }}</button>
    </div>`,
  },
}));

const teamA = { id: 1, name: 'Time A' };
const teamB = { id: 2, name: 'Time B' };
const teamC = { id: 3, name: 'Time C' };

const LABEL_A1 = { id: 1, title: 'urgent', color: 'red', team_id: 1 };
const LABEL_B1 = { id: 2, title: 'vip', color: 'blue', team_id: 2 };
const LABEL_A2 = { id: 3, title: 'novo', color: 'green', team_id: 1 };
const LABEL_LEGACY = { id: 4, title: 'legado', color: 'gray', team_id: null };

const buildStore = ({
  currentRole = 'agent',
  myTeams = [],
  contactTeamsById = {},
  contactLabelsById = {},
  labels = [LABEL_A1],
  contextTeam = reactive({ value: null }),
  conversationsById = {},
  updateAction = () => {},
  teamsAction = () => {},
} = {}) =>
  createStore({
    getters: {
      getCurrentRole: () => currentRole,
      'labels/getLabels': () => labels,
      'contactLabels/getContactLabels': () => id =>
        contactLabelsById[Number(id)] || [],
      'teams/getMyTeams': () => myTeams,
      'contactTeams/getTeams': () => id => contactTeamsById[Number(id)] || [],
      'teamContext/getSelectedTeamId': () => contextTeam.value,
      'contactConversations/getContactConversation': () => id =>
        conversationsById[Number(id)] || [],
    },
    actions: {
      'contactLabels/get': () => {},
      'contactTeams/get': teamsAction,
      'teams/get': () => {},
      'contactLabels/update': updateAction,
    },
  });

const mountContactLabels = (contactId, storeOptions) => {
  useRoute.mockReturnValue({ params: { contactId: String(contactId) } });

  return mount(ContactLabels, {
    props: { contactId },
    global: {
      plugins: [buildStore(storeOptions)],
    },
  });
};

const menuItems = wrapper =>
  wrapper.findComponent({ name: 'AddLabel' }).props('labelMenuItems');
const menuValues = wrapper => menuItems(wrapper).map(i => i.value);

describe('ContactLabels - team selector', () => {
  it('shows the team when the agent shares exactly one team with the contact, selected automatically', () => {
    const wrapper = mountContactLabels(10, {
      myTeams: [teamA],
      contactTeamsById: { 10: [teamA] },
    });

    const select = wrapper.find('select');
    expect(select.exists()).toBe(true);
    expect(select.findAll('option').map(o => o.text())).toEqual(['Time A']);
    expect(select.element.value).toBe(String(teamA.id));
  });

  it('hides the selector and the add button when the agent has no team in common with the contact', () => {
    const wrapper = mountContactLabels(10, {
      myTeams: [teamB],
      contactTeamsById: { 10: [teamA] },
    });

    expect(wrapper.find('select').exists()).toBe(false);
    expect(wrapper.find('.add-label-stub').exists()).toBe(false);
  });

  it('shows only the team the agent is a member of when the contact has two teams', () => {
    const wrapper = mountContactLabels(10, {
      myTeams: [teamA],
      contactTeamsById: { 10: [teamA, teamB] },
    });

    const select = wrapper.find('select');
    expect(select.findAll('option').map(o => o.text())).toEqual(['Time A']);
  });

  it('shows both of the contact teams to an administrator, ignoring their own membership', () => {
    const wrapper = mountContactLabels(10, {
      currentRole: 'administrator',
      myTeams: [teamA],
      contactTeamsById: { 10: [teamA, teamB] },
    });

    const select = wrapper.find('select');
    expect(select.findAll('option').map(o => o.text())).toEqual([
      'Time A',
      'Time B',
    ]);
  });

  it('hides the selector and the add button when the contact has no conversations with a team', () => {
    const wrapper = mountContactLabels(10, {
      myTeams: [teamA],
      contactTeamsById: { 10: [] },
    });

    expect(wrapper.find('select').exists()).toBe(false);
    expect(wrapper.find('.add-label-stub').exists()).toBe(false);
  });

  it('recomputes the options when switching from one contact to another, without inheriting the previous selection', async () => {
    const wrapper = mountContactLabels(10, {
      myTeams: [teamA, teamB],
      contactTeamsById: { 10: [teamA], 20: [teamB] },
    });

    expect(wrapper.find('select').element.value).toBe(String(teamA.id));

    await wrapper.setProps({ contactId: 20 });

    const select = wrapper.find('select');
    expect(select.findAll('option').map(o => o.text())).toEqual(['Time B']);
    expect(select.element.value).toBe(String(teamB.id));
  });

  it('dispatches the exact selected team_id when tagging', async () => {
    const updateAction = vi.fn();
    const wrapper = mountContactLabels(10, {
      myTeams: [teamA, teamB],
      contactTeamsById: { 10: [teamA, teamB] },
      labels: [LABEL_A1, LABEL_B1],
      updateAction,
    });

    await wrapper.find('select').setValue(String(teamB.id));
    await wrapper.find('.add-first').trigger('click');

    expect(updateAction).toHaveBeenCalledTimes(1);
    const [, payload] = updateAction.mock.calls[0];
    expect(payload.teamId).toBe(teamB.id);
  });
});

describe('ContactLabels - menu, payloads and context', () => {
  const both = { 10: [teamA, teamB] };

  it('filters the menu by the selected team and follows the selector', async () => {
    const wrapper = mountContactLabels(10, {
      currentRole: 'administrator',
      contactTeamsById: both,
      labels: [LABEL_A1, LABEL_B1],
    });
    expect(menuValues(wrapper)).toEqual([1]);

    await wrapper.find('select').setValue(String(teamB.id));
    expect(menuValues(wrapper)).toEqual([2]);
  });

  it('never lists labels without team_id in the menu', () => {
    const wrapper = mountContactLabels(10, {
      currentRole: 'administrator',
      contactTeamsById: both,
      labels: [LABEL_A1, LABEL_LEGACY],
    });
    expect(menuValues(wrapper)).toEqual([1]);
  });

  it('flags isSelected and sorts unselected first', () => {
    const wrapper = mountContactLabels(10, {
      currentRole: 'administrator',
      contactTeamsById: both,
      labels: [LABEL_A1, LABEL_A2],
      contactLabelsById: { 10: ['urgent'] },
    });
    expect(menuItems(wrapper).map(i => [i.value, i.isSelected])).toEqual([
      [3, false],
      [1, true],
    ]);
  });

  it('adds with the full contact titles and the selected team', async () => {
    const updateAction = vi.fn();
    const wrapper = mountContactLabels(10, {
      currentRole: 'administrator',
      contactTeamsById: both,
      labels: [LABEL_A1, LABEL_A2],
      contactLabelsById: { 10: ['urgent'] },
      updateAction,
    });
    await wrapper.find('[data-test="item-3"]').trigger('click');
    expect(updateAction.mock.calls[0][1]).toEqual({
      contactId: 10,
      labels: ['urgent', 'novo'],
      teamId: 1,
    });
  });

  it('removes using the label team_id, not the selector team', async () => {
    const updateAction = vi.fn();
    const wrapper = mountContactLabels(10, {
      currentRole: 'administrator',
      contactTeamsById: both,
      labels: [LABEL_A1, LABEL_B1],
      contactLabelsById: { 10: ['urgent', 'vip'] },
      updateAction,
    });
    wrapper
      .findAllComponents(LabelItem)
      .find(c => c.props('label').id === 2)
      .vm.$emit('remove', LABEL_B1);
    await wrapper.vm.$nextTick();
    expect(updateAction.mock.calls[0][1]).toEqual({
      contactId: 10,
      labels: ['urgent'],
      teamId: 2,
    });
  });

  it('keeps labels invisible to the agent when adding and removing', async () => {
    const updateAction = vi.fn();
    const wrapper = mountContactLabels(10, {
      myTeams: [teamA],
      contactTeamsById: { 10: [teamA] },
      labels: [LABEL_A1, LABEL_A2],
      contactLabelsById: { 10: ['urgent', 'hidden-b'] },
      updateAction,
    });
    await wrapper.find('[data-test="item-3"]').trigger('click');
    expect(updateAction.mock.calls[0][1].labels).toEqual([
      'urgent',
      'hidden-b',
      'novo',
    ]);

    wrapper.findComponent(LabelItem).vm.$emit('remove', LABEL_A1);
    await wrapper.vm.$nextTick();
    expect(updateAction.mock.calls[1][1].labels).toEqual(['hidden-b']);
  });

  it('keeps chips removable (teamId null for legacy) without add button', async () => {
    const updateAction = vi.fn();
    const wrapper = mountContactLabels(10, {
      contactTeamsById: { 10: [] },
      labels: [LABEL_LEGACY],
      contactLabelsById: { 10: ['legado'] },
      updateAction,
    });
    expect(wrapper.find('.add-label-stub').exists()).toBe(false);
    expect(wrapper.findAllComponents(LabelItem)).toHaveLength(1);

    wrapper.findComponent(LabelItem).vm.$emit('remove', LABEL_LEGACY);
    await wrapper.vm.$nextTick();
    expect(updateAction.mock.calls[0][1]).toEqual({
      contactId: 10,
      labels: [],
      teamId: null,
    });
  });

  it('preselects the context team when it is an option', () => {
    const wrapper = mountContactLabels(10, {
      currentRole: 'administrator',
      contactTeamsById: both,
      contextTeam: reactive({ value: 2 }),
    });
    expect(wrapper.find('select').element.value).toBe('2');
  });

  it('falls back to the first option when context is outside the options or null', () => {
    const outside = mountContactLabels(10, {
      currentRole: 'administrator',
      contactTeamsById: both,
      contextTeam: reactive({ value: teamC.id }),
    });
    expect(outside.find('select').element.value).toBe('1');

    const none = mountContactLabels(10, {
      currentRole: 'administrator',
      contactTeamsById: both,
    });
    expect(none.find('select').element.value).toBe('1');
  });

  it('does not override a manual choice when the context changes later', async () => {
    const contextTeam = reactive({ value: 2 });
    const wrapper = mountContactLabels(10, {
      currentRole: 'administrator',
      contactTeamsById: both,
      contextTeam,
    });
    await wrapper.find('select').setValue('1');
    contextTeam.value = 2;
    await wrapper.vm.$nextTick();
    expect(wrapper.find('select').element.value).toBe('1');
  });

  it('applies the context team on contact switch and keeps the old one if still an option', async () => {
    const wrapper = mountContactLabels(10, {
      currentRole: 'administrator',
      contactTeamsById: { 10: [teamA], 20: [teamB, teamC], 30: [teamC, teamB] },
      contextTeam: reactive({ value: 3 }),
    });
    expect(wrapper.find('select').element.value).toBe('1');

    await wrapper.setProps({ contactId: 20 });
    expect(wrapper.find('select').element.value).toBe('3');

    // 3 is still an option for contact 30, so the selection is kept
    await wrapper.find('select').setValue('2');
    await wrapper.setProps({ contactId: 30 });
    expect(wrapper.find('select').element.value).toBe('2');
  });

  it('refetches contact teams when the contact conversations grow', async () => {
    const teamsAction = vi.fn();
    const conversationsById = reactive({ 10: [{ id: 1 }] });
    const wrapper = mountContactLabels(10, {
      currentRole: 'administrator',
      contactTeamsById: both,
      conversationsById,
      teamsAction,
    });
    const initial = teamsAction.mock.calls.length;

    conversationsById[10] = [{ id: 3 }];
    await wrapper.vm.$nextTick();
    expect(teamsAction.mock.calls.length).toBe(initial);

    conversationsById[10] = [{ id: 1 }, { id: 2 }];
    await wrapper.vm.$nextTick();
    expect(teamsAction.mock.calls.length).toBe(initial + 1);
    expect(teamsAction.mock.calls.at(-1)[1]).toBe(10);
  });
});
