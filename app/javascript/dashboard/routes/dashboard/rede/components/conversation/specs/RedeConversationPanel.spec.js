import { mount, flushPromises } from '@vue/test-utils';
import PeopleAPI from 'dashboard/api/rede/people';
import ProjectsAPI from 'dashboard/api/rede/projects';
import ParticipationsAPI from 'dashboard/api/rede/participations';
import InteractionsAPI from 'dashboard/api/rede/interactions';
import EvaluationsAPI from 'dashboard/api/rede/evaluations';
import RedeConversationPanel from '../RedeConversationPanel.vue';

vi.mock('dashboard/api/rede/people', () => ({ default: { show: vi.fn() } }));
vi.mock('dashboard/api/rede/projects', () => ({ default: { get: vi.fn() } }));
vi.mock('dashboard/api/rede/participations', () => ({
  default: { create: vi.fn(), update: vi.fn() },
}));
vi.mock('dashboard/api/rede/interactions', () => ({
  default: { create: vi.fn() },
}));
vi.mock('dashboard/api/rede/evaluations', () => ({
  default: { create: vi.fn() },
}));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({ value: { id: 1, name: 'Bia' } }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
const mockPush = vi.fn();
vi.mock('vue-router', () => ({ useRouter: () => ({ push: mockPush }) }));

const projectsList = [
  {
    id: 2,
    name: 'PE',
    color: '#ff0000',
    status: 'active',
    team_id: 20,
    fronts: [
      { id: 10, name: 'Campo', status: 'active', has_temperature: true },
      { id: 11, name: 'Digital', status: 'active', has_temperature: false },
    ],
  },
  {
    id: 3,
    name: 'PA',
    color: '#00ff00',
    status: 'active',
    team_id: 30,
    fronts: [],
  },
  {
    id: 4,
    name: 'Velho',
    color: '#0000ff',
    status: 'closed',
    team_id: 40,
    fronts: [],
  },
];

const participation = (projectId, teamId, extra = {}) => ({
  id: projectId * 100,
  status: 'active',
  project: {
    id: projectId,
    name: projectId === 2 ? 'PE' : 'PA',
    color: '#ff0000',
    status: 'active',
    team_id: teamId,
    has_fronts: projectId === 2,
  },
  responsible: { id: 9, name: 'Carla' },
  next_step: 'ligar',
  last_contact_at: null,
  assignments:
    projectId === 2
      ? [
          {
            id: 1,
            front: { id: 10, name: 'Campo' },
            temperature: 'quente',
          },
          {
            id: 2,
            front: { id: 11, name: 'Digital' },
            temperature: null,
          },
        ]
      : [],
  project_temperature: projectId === 2 ? null : 'morno',
  front_pending: false,
  ...extra,
});

const person = (...participations) => ({
  data: { contact: { id: 5, name: 'Ana' }, participations },
});

const notFound = () =>
  Promise.reject(
    Object.assign(new Error('404'), { response: { status: 404 } })
  );

const stubs = {
  CallDialog: {
    template: '<div data-test="call-dialog" />',
    props: ['projects', 'frontsByProject', 'authorName'],
    emits: ['submit'],
    methods: { open() {}, close() {} },
  },
  NoteDialog: {
    template: '<div data-test="note-dialog" />',
    props: ['projects', 'frontsByProject'],
    emits: ['submit'],
    methods: { open() {}, close() {} },
  },
};

const factory = (props = {}) =>
  mount(RedeConversationPanel, {
    props: { conversationId: 1, contactId: 5, teamId: 20, ...props },
    global: { stubs },
  });

describe('RedeConversationPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    ProjectsAPI.get.mockResolvedValue({ data: projectsList });
    PeopleAPI.show.mockResolvedValue(
      person(participation(2, 20), participation(3, 30))
    );
    ParticipationsAPI.create.mockResolvedValue({ data: {} });
    ParticipationsAPI.update.mockResolvedValue({ data: {} });
    InteractionsAPI.create.mockResolvedValue({ data: {} });
    EvaluationsAPI.create.mockResolvedValue({ data: {} });
  });

  it('shows only the participation of the conversation team', async () => {
    const wrapper = factory({ teamId: 30 });
    await flushPromises();
    expect(wrapper.text()).toContain('PA');
    expect(wrapper.text()).not.toContain('Campo');
    expect(wrapper.find('[data-test="crm-participating"]').exists()).toBe(true);
  });

  it('shows fronts, temperature, responsible and next step', async () => {
    const wrapper = factory();
    await flushPromises();
    const text = wrapper.text();
    expect(text).toContain('PE');
    expect(text).toContain('Campo');
    expect(text).toContain('Hot');
    expect(text).toContain('Carla');
    expect(wrapper.find('input[data-test="next-step"]').element.value).toBe(
      'ligar'
    );
    // Só a frente com temperatura tem o seletor.
    expect(wrapper.findAll('[data-test="temperature-select"]')).toHaveLength(1);
  });

  it('shows the project temperature when the project has no fronts', async () => {
    const wrapper = factory({ teamId: 30 });
    await flushPromises();
    expect(wrapper.find('[data-test="project-temperature"]').exists()).toBe(
      true
    );
    expect(wrapper.findAll('[data-test="temperature-select"]')).toHaveLength(1);
  });

  it('shows the pending front notice', async () => {
    PeopleAPI.show.mockResolvedValue(
      person(participation(2, 20, { assignments: [], front_pending: true }))
    );
    const wrapper = factory();
    await flushPromises();
    expect(wrapper.find('[data-test="front-pending"]').exists()).toBe(true);
  });

  it('shows the not-in-project state on a 404 and adds the person', async () => {
    PeopleAPI.show.mockImplementationOnce(notFound);
    const wrapper = factory();
    await flushPromises();
    expect(wrapper.find('[data-test="crm-outside"]').text()).toContain('PE');
    await wrapper.find('[data-test="crm-add"]').trigger('click');
    await flushPromises();
    expect(ParticipationsAPI.create).toHaveBeenCalledWith({
      project_id: 2,
      contact_id: 5,
    });
    // Recarrega o painel depois de adicionar.
    expect(PeopleAPI.show).toHaveBeenCalledTimes(2);
    expect(wrapper.find('[data-test="crm-participating"]').exists()).toBe(true);
  });

  it('shows the not-in-project state when the profile lacks the project', async () => {
    PeopleAPI.show.mockResolvedValue(person(participation(3, 30)));
    const wrapper = factory();
    await flushPromises();
    expect(wrapper.find('[data-test="crm-outside"]').exists()).toBe(true);
  });

  it('hides the add button when the project is closed', async () => {
    PeopleAPI.show.mockImplementationOnce(notFound);
    const wrapper = factory({ teamId: 40 });
    await flushPromises();
    expect(wrapper.find('[data-test="crm-outside"]').exists()).toBe(true);
    expect(wrapper.find('[data-test="crm-add"]').exists()).toBe(false);
  });

  it('shows the notice and calls nothing when the conversation has no team', async () => {
    const wrapper = factory({ teamId: null });
    await flushPromises();
    expect(wrapper.find('[data-test="crm-no-project"]').exists()).toBe(true);
    expect(PeopleAPI.show).not.toHaveBeenCalled();
    expect(ProjectsAPI.get).not.toHaveBeenCalled();
  });

  it('shows the notice when the team has no visible project', async () => {
    const wrapper = factory({ teamId: 99 });
    await flushPromises();
    expect(wrapper.find('[data-test="crm-no-project"]').exists()).toBe(true);
  });

  it('shows an error with retry on network failure', async () => {
    ProjectsAPI.get.mockRejectedValueOnce(new Error('boom'));
    const wrapper = factory();
    await flushPromises();
    expect(wrapper.find('[data-test="crm-error"]').exists()).toBe(true);
    await wrapper.find('[data-test="crm-retry"]').trigger('click');
    await flushPromises();
    expect(wrapper.find('[data-test="crm-participating"]').exists()).toBe(true);
  });

  it('does not let a stale response overwrite the current conversation', async () => {
    let resolveFirst;
    PeopleAPI.show.mockImplementationOnce(
      () =>
        new Promise(resolve => {
          resolveFirst = resolve;
        })
    );
    const wrapper = factory({ contactId: 5, teamId: 20 });
    await wrapper.setProps({ conversationId: 2, contactId: 6, teamId: 30 });
    await flushPromises();
    expect(wrapper.text()).toContain('PA');
    resolveFirst(person(participation(2, 20)));
    await flushPromises();
    expect(wrapper.text()).toContain('PA');
    expect(wrapper.text()).not.toContain('Campo');
  });

  it('saves the next step on blur', async () => {
    const wrapper = factory();
    await flushPromises();
    const input = wrapper.find('input[data-test="next-step"]');
    await input.setValue('visitar');
    await input.trigger('blur');
    await flushPromises();
    expect(ParticipationsAPI.update).toHaveBeenCalledWith(200, {
      next_step: 'visitar',
    });
  });

  it('logs a call with the project fixed and reloads', async () => {
    const wrapper = factory();
    await flushPromises();
    const dialog = wrapper.findComponent(stubs.CallDialog);
    expect(dialog.props('projects')).toEqual([{ id: 2, name: 'PE' }]);
    dialog.vm.$emit('submit', {
      projectId: 2,
      answered: true,
      occurredAt: '2026-11-16T12:00:00.000Z',
    });
    await flushPromises();
    expect(InteractionsAPI.create).toHaveBeenCalledWith(
      expect.objectContaining({
        project_id: 2,
        contact_id: 5,
        kind: 'call',
        answered: true,
      })
    );
    expect(PeopleAPI.show).toHaveBeenCalledTimes(2);
  });

  it('adds a note', async () => {
    const wrapper = factory();
    await flushPromises();
    wrapper
      .findComponent(stubs.NoteDialog)
      .vm.$emit('submit', { projectId: 2, summary: 'oi' });
    await flushPromises();
    expect(InteractionsAPI.create).toHaveBeenCalledWith(
      expect.objectContaining({ kind: 'note', summary: 'oi', project_id: 2 })
    );
  });

  it('saves a temperature for the front', async () => {
    const wrapper = factory();
    await flushPromises();
    await wrapper
      .find('[data-test="temperature-select"] select')
      .setValue('frio');
    await wrapper.find('[data-test="temperature-save"]').trigger('click');
    await flushPromises();
    expect(EvaluationsAPI.create).toHaveBeenCalledWith(
      expect.objectContaining({
        project_id: 2,
        contact_id: 5,
        front_id: 10,
        level: 'frio',
      })
    );
  });

  it('opens the profile', async () => {
    const wrapper = factory();
    await flushPromises();
    await wrapper.find('[data-test="crm-open-profile"]').trigger('click');
    expect(mockPush).toHaveBeenCalledWith({
      name: 'rede_person',
      params: { contactId: 5 },
    });
  });
});
