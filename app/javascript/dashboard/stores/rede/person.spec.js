import { setActivePinia, createPinia } from 'pinia';
import PeopleAPI from 'dashboard/api/rede/people';
import EvaluationsAPI from 'dashboard/api/rede/evaluations';
import InteractionsAPI from 'dashboard/api/rede/interactions';
import AssignmentsAPI from 'dashboard/api/rede/assignments';
import ParticipationsAPI from 'dashboard/api/rede/participations';
import { useRedePersonStore } from './person';

vi.mock('dashboard/api/rede/people', () => ({
  default: { show: vi.fn(), timeline: vi.fn() },
}));
vi.mock('dashboard/api/rede/evaluations', () => ({
  default: { create: vi.fn() },
}));
vi.mock('dashboard/api/rede/interactions', () => ({
  default: { create: vi.fn() },
}));
vi.mock('dashboard/api/rede/assignments', () => ({
  default: { create: vi.fn(), update: vi.fn(), close: vi.fn() },
}));
vi.mock('dashboard/api/rede/participations', () => ({
  default: { create: vi.fn(), update: vi.fn() },
}));

vi.mock('dashboard/store/utils/api', () => ({
  throwErrorMessage: vi.fn(error => {
    throw error;
  }),
}));

const apiProfile = {
  contact: {
    id: 1,
    name: 'Ana',
    additional_attributes: { city_name: 'Recife' },
  },
  participations: [{ id: 7, project_id: 2, next_step: 'ligar' }],
};

const apiTimeline = (cursor = null) => ({
  data: {
    payload: [{ type: 'note', occurred_at: '2026-11-01T10:00:00Z', data: {} }],
    meta: { limit: 20, next_cursor: cursor },
  },
});

describe('rede person store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    PeopleAPI.show.mockResolvedValue({ data: apiProfile });
    PeopleAPI.timeline.mockResolvedValue(apiTimeline());
  });

  it('show loads the profile keeping contact attributes untouched', async () => {
    const store = useRedePersonStore();
    await store.show(1);
    expect(PeopleAPI.show).toHaveBeenCalledWith(1);
    expect(store.person.contact.name).toBe('Ana');
    expect(store.person.contact.additionalAttributes).toEqual({
      city_name: 'Recife',
    });
    expect(store.person.participations[0].nextStep).toBe('ligar');
    expect(store.uiFlags.fetchingItem).toBe(false);
  });

  it('show clears the flag and rethrows on error', async () => {
    PeopleAPI.show.mockRejectedValue(new Error('404'));
    const store = useRedePersonStore();
    await expect(store.show(1)).rejects.toThrow('404');
    expect(store.uiFlags.fetchingItem).toBe(false);
  });

  it('getTimeline replaces the events and keeps the cursor', async () => {
    PeopleAPI.timeline.mockResolvedValue(apiTimeline('abc'));
    const store = useRedePersonStore();
    await store.getTimeline(1, { project_id: 2 });
    expect(PeopleAPI.timeline).toHaveBeenCalledWith(1, { project_id: 2 });
    expect(store.timeline).toHaveLength(1);
    expect(store.timeline[0].occurredAt).toBe('2026-11-01T10:00:00Z');
    expect(store.timelineMeta).toEqual({ limit: 20, nextCursor: 'abc' });
    expect(store.uiFlags.fetchingTimeline).toBe(false);
  });

  it('loadMoreTimeline appends using the cursor', async () => {
    const store = useRedePersonStore();
    PeopleAPI.timeline.mockResolvedValueOnce(apiTimeline('abc'));
    await store.getTimeline(1, { project_id: 2 });
    PeopleAPI.timeline.mockResolvedValueOnce(apiTimeline(null));
    await store.loadMoreTimeline(1, { project_id: 2 });
    expect(PeopleAPI.timeline).toHaveBeenLastCalledWith(1, {
      project_id: 2,
      before: 'abc',
    });
    expect(store.timeline).toHaveLength(2);
    expect(store.timelineMeta.nextCursor).toBeNull();
  });

  it('loadMoreTimeline does nothing without a cursor', async () => {
    const store = useRedePersonStore();
    await store.getTimeline(1);
    PeopleAPI.timeline.mockClear();
    await store.loadMoreTimeline(1);
    expect(PeopleAPI.timeline).not.toHaveBeenCalled();
  });

  it('getTimeline rethrows on error and clears the flag', async () => {
    PeopleAPI.timeline.mockRejectedValue(new Error('bad'));
    const store = useRedePersonStore();
    await expect(store.getTimeline(1)).rejects.toThrow('bad');
    expect(store.uiFlags.fetchingTimeline).toBe(false);
  });

  it('setTemperature creates an evaluation and refreshes', async () => {
    EvaluationsAPI.create.mockResolvedValue({ data: { id: 1 } });
    const store = useRedePersonStore();
    await store.setTemperature({
      projectId: 2,
      contactId: 1,
      frontId: 5,
      level: 'quente',
      note: 'x',
    });
    expect(EvaluationsAPI.create).toHaveBeenCalledWith({
      project_id: 2,
      contact_id: 1,
      front_id: 5,
      level: 'quente',
      note: 'x',
    });
    expect(PeopleAPI.show).toHaveBeenCalledWith(1);
    expect(PeopleAPI.timeline).toHaveBeenCalled();
    expect(store.uiFlags.savingAction).toBe(false);
  });

  it('logCall creates a call interaction', async () => {
    InteractionsAPI.create.mockResolvedValue({ data: { id: 1 } });
    const store = useRedePersonStore();
    await store.logCall({
      projectId: 2,
      contactId: 1,
      answered: true,
      summary: 'ok',
    });
    expect(InteractionsAPI.create).toHaveBeenCalledWith({
      project_id: 2,
      contact_id: 1,
      front_id: undefined,
      kind: 'call',
      answered: true,
      summary: 'ok',
      occurred_at: undefined,
    });
    expect(PeopleAPI.show).toHaveBeenCalledWith(1);
  });

  it('addNote creates a note interaction', async () => {
    InteractionsAPI.create.mockResolvedValue({ data: { id: 1 } });
    const store = useRedePersonStore();
    await store.addNote({ projectId: 2, contactId: 1, summary: 'oi' });
    expect(InteractionsAPI.create).toHaveBeenCalledWith(
      expect.objectContaining({ kind: 'note', summary: 'oi', contact_id: 1 })
    );
  });

  it('createAssignment, updateAssignment and closeAssignment call the API', async () => {
    AssignmentsAPI.create.mockResolvedValue({ data: {} });
    AssignmentsAPI.update.mockResolvedValue({ data: {} });
    AssignmentsAPI.close.mockResolvedValue({ data: {} });
    const store = useRedePersonStore();
    await store.createAssignment({
      contactId: 1,
      participationId: 7,
      frontId: 5,
      roleId: 3,
      superiorContactId: 8,
    });
    expect(AssignmentsAPI.create).toHaveBeenCalledWith(7, {
      front_id: 5,
      role_id: 3,
      superior_contact_id: 8,
    });
    await store.updateAssignment({
      contactId: 1,
      participationId: 7,
      id: 9,
      roleId: 4,
    });
    expect(AssignmentsAPI.update).toHaveBeenCalledWith(7, 9, { role_id: 4 });
    await store.closeAssignment({ contactId: 1, participationId: 7, id: 9 });
    expect(AssignmentsAPI.close).toHaveBeenCalledWith(7, 9);
  });

  it('createParticipation and updateParticipation call the API', async () => {
    ParticipationsAPI.create.mockResolvedValue({ data: {} });
    ParticipationsAPI.update.mockResolvedValue({ data: {} });
    const store = useRedePersonStore();
    await store.createParticipation({
      projectId: 2,
      contactId: 1,
      assignment: { front_id: 5 },
    });
    expect(ParticipationsAPI.create).toHaveBeenCalledWith({
      project_id: 2,
      contact_id: 1,
      assignment: { front_id: 5 },
    });
    await store.updateParticipation({
      contactId: 1,
      id: 7,
      nextStep: 'ligar',
      responsibleUserId: 3,
    });
    expect(ParticipationsAPI.update).toHaveBeenCalledWith(7, {
      next_step: 'ligar',
      responsible_user_id: 3,
    });
  });

  it('an action failure rethrows, clears the flag and skips the refresh', async () => {
    EvaluationsAPI.create.mockRejectedValue(new Error('422'));
    const store = useRedePersonStore();
    await expect(
      store.setTemperature({ projectId: 2, contactId: 1, level: 'x' })
    ).rejects.toThrow('422');
    expect(store.uiFlags.savingAction).toBe(false);
    expect(PeopleAPI.show).not.toHaveBeenCalled();
  });

  it('reset clears the person', async () => {
    const store = useRedePersonStore();
    await store.show(1);
    store.reset();
    expect(store.person).toEqual({});
    expect(store.timeline).toEqual([]);
  });
});
