import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import OverviewReportFilters from '../OverviewReportFilters.vue';
import teamContext from 'dashboard/store/modules/teamContext';

const routeMock = { query: {} };
const replaceMock = vi.fn();

vi.mock('vue-router', () => ({
  useRoute: () => routeMock,
  useRouter: () => ({ replace: replaceMock }),
}));

const ALL_TEAMS = [
  { id: 3, name: 'Team 3' },
  { id: 7, name: 'Team 7' },
];
const MY_TEAMS = [{ id: 7, name: 'Team 7' }];

const mountComponent = ({ role = 'administrator', contextId = null } = {}) => {
  const store = createStore({
    modules: {
      teamContext: {
        ...teamContext,
        state: () => ({ selectedTeamId: contextId }),
      },
    },
    getters: {
      getCurrentRole: () => role,
      'teams/getTeams': () => ALL_TEAMS,
      'teams/getMyTeams': () => MY_TEAMS,
    },
  });
  return mount(OverviewReportFilters, {
    global: {
      plugins: [store],
      mocks: { $t: key => key },
      stubs: {
        WootDatePicker: {
          name: 'WootDatePicker',
          template: '<div class="date-picker" />',
        },
        ToggleSwitch: true,
        ComboBox: {
          name: 'ComboBox',
          props: ['options', 'modelValue'],
          emits: ['update:modelValue'],
          template: '<div class="combo" />',
        },
      },
    },
  });
};

const lastEmit = wrapper => wrapper.emitted('filterChange').at(-1)[0];
const lastQuery = () => replaceMock.mock.calls.at(-1)[0].query;
const combo = wrapper => wrapper.findComponent({ name: 'ComboBox' });

describe('OverviewReportFilters team filter', () => {
  beforeEach(() => {
    routeMock.query = {};
    replaceMock.mockClear();
  });

  it('emits null team and omits team from URL without URL param or context', () => {
    const wrapper = mountComponent();
    expect(lastEmit(wrapper).team).toBeNull();
    expect(lastQuery()).not.toHaveProperty('team');
  });

  it('applies the sidebar team context when there is no ?team', () => {
    const wrapper = mountComponent({ contextId: 7 });
    expect(lastEmit(wrapper).team).toBe(7);
    expect(lastQuery().team).toBe(7);
  });

  it('prefers ?team over the context', () => {
    routeMock.query = { team: '3' };
    const wrapper = mountComponent({ contextId: 7 });
    expect(lastEmit(wrapper).team).toBe(3);
    expect(lastQuery().team).toBe(3);
  });

  it('keeps no filter and team=all when ?team=all with context', () => {
    routeMock.query = { team: 'all' };
    const wrapper = mountComponent({ contextId: 7 });
    expect(lastEmit(wrapper).team).toBeNull();
    expect(lastQuery().team).toBe('all');
  });

  it('changes team on selection preserving other params', async () => {
    routeMock.query = {
      from: '1738607400',
      to: '1770229799',
      range: 'last7days',
      business_hours: 'true',
    };
    const wrapper = mountComponent();
    combo(wrapper).vm.$emit('update:modelValue', 3);
    await wrapper.vm.$nextTick();
    expect(lastEmit(wrapper).team).toBe(3);
    const query = lastQuery();
    expect(query.team).toBe(3);
    expect(query.from).toBe(1738540800);
    expect(query.to).toBe(1770249599);
    expect(query.range).toBe('last7days');
    expect(query.business_hours).toBe('true');
  });

  it('writes team=all when clearing with context present', async () => {
    const wrapper = mountComponent({ contextId: 7 });
    combo(wrapper).vm.$emit('update:modelValue', '');
    await wrapper.vm.$nextTick();
    expect(lastEmit(wrapper).team).toBeNull();
    expect(lastQuery().team).toBe('all');
  });

  it('omits team when clearing without context', async () => {
    routeMock.query = { team: '3' };
    const wrapper = mountComponent();
    combo(wrapper).vm.$emit('update:modelValue', '');
    await wrapper.vm.$nextTick();
    expect(lastEmit(wrapper).team).toBeNull();
    expect(lastQuery()).not.toHaveProperty('team');
  });

  it('keeps team when the date range changes', async () => {
    routeMock.query = { team: '3' };
    const wrapper = mountComponent();
    wrapper
      .findComponent({ name: 'WootDatePicker' })
      .vm.$emit('dateRangeChanged', [
        new Date(2026, 0, 1),
        new Date(2026, 0, 5),
        'custom',
      ]);
    await wrapper.vm.$nextTick();
    expect(lastQuery().team).toBe(3);
    expect(lastEmit(wrapper).team).toBe(3);
  });

  it('uses getTeams for admins and getMyTeams for agents', () => {
    const admin = mountComponent({ role: 'administrator' });
    expect(combo(admin).props('options')).toEqual([
      { value: 3, label: 'Team 3' },
      { value: 7, label: 'Team 7' },
    ]);
    const agent = mountComponent({ role: 'agent' });
    expect(combo(agent).props('options')).toEqual([
      { value: 7, label: 'Team 7' },
    ]);
  });
});
