import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { useRoute } from 'vue-router';
import ContactLabels from '../ContactLabels.vue';

vi.mock('vue-router');

// AddLabel.vue pulls in DropdownMenu and its own import graph, unrelated to
// what this spec exercises (the team selector). Stub it with a button that
// emits the same `update-label` event AddLabel emits when a menu item is
// clicked, so handleLabelAction can be triggered directly in tests.
vi.mock('dashboard/components-next/label/AddLabel.vue', () => ({
  default: {
    props: ['labelMenuItems'],
    emits: ['updateLabel'],
    template:
      '<button class="add-label-stub" @click="$emit(\'updateLabel\', { value: labelMenuItems[0]?.value })">add label</button>',
  },
}));

const LABEL_URGENT = { id: 1, title: 'urgent', color: 'red' };

const buildStore = ({
  currentRole = 'agent',
  myTeams = [],
  contactTeamsById = {},
  contactLabelsById = {},
  labels = [LABEL_URGENT],
  updateAction = () => {},
} = {}) =>
  createStore({
    getters: {
      getCurrentRole: () => currentRole,
      'labels/getLabels': () => labels,
      'contactLabels/getContactLabels': () => id =>
        contactLabelsById[Number(id)] || [],
      'teams/getMyTeams': () => myTeams,
      'contactTeams/getTeams': () => id => contactTeamsById[Number(id)] || [],
    },
    actions: {
      'contactLabels/get': () => {},
      'contactTeams/get': () => {},
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

describe('ContactLabels - team selector', () => {
  const teamA = { id: 1, name: 'Time A' };
  const teamB = { id: 2, name: 'Time B' };

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

  it('hides the selector when the agent has no team in common with the contact, and still allows tagging without team_id', async () => {
    const updateAction = vi.fn();
    const wrapper = mountContactLabels(10, {
      myTeams: [teamB],
      contactTeamsById: { 10: [teamA] },
      updateAction,
    });

    expect(wrapper.find('select').exists()).toBe(false);

    await wrapper.find('.add-label-stub').trigger('click');

    expect(updateAction).toHaveBeenCalledTimes(1);
    const [, payload] = updateAction.mock.calls[0];
    expect(payload.teamId).toBeNull();
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

  it('hides the selector when the contact has no conversations with a team', () => {
    const wrapper = mountContactLabels(10, {
      myTeams: [teamA],
      contactTeamsById: { 10: [] },
    });

    expect(wrapper.find('select').exists()).toBe(false);
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
      updateAction,
    });

    await wrapper.find('select').setValue(String(teamB.id));
    await wrapper.find('.add-label-stub').trigger('click');

    expect(updateAction).toHaveBeenCalledTimes(1);
    const [, payload] = updateAction.mock.calls[0];
    expect(payload.teamId).toBe(teamB.id);
  });
});
