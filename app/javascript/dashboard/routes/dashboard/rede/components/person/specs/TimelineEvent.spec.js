import { mount, RouterLinkStub } from '@vue/test-utils';
import TimelineEvent from '../TimelineEvent.vue';

const project = { id: 2, name: 'PE', color: '#ff0000' };

const make = (type, data, extra = {}) => ({
  type,
  occurredAt: '2026-11-16T10:00:00Z',
  project,
  front: null,
  author: { id: 5, name: 'Bia' },
  data,
  ...extra,
});

const factory = (event, props = {}) =>
  mount(TimelineEvent, {
    props: { event, currentUserId: 5, accountId: 1, ...props },
    global: { stubs: { RouterLink: RouterLinkStub } },
  });

const iconClasses = wrapper =>
  wrapper.find('[data-test="event-icon"]').classes();

describe('TimelineEvent', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-11-16T12:00:00Z'));
  });
  afterEach(() => vi.useRealTimers());

  it('renders a conversation with a link', () => {
    const wrapper = factory(
      make('conversation', {
        conversationId: 90,
        displayId: 123,
        inbox: { id: 1, name: 'Caixa X' },
      })
    );
    expect(wrapper.text()).toContain('Conversation #123 in Caixa X');
    expect(iconClasses(wrapper)).toContain('i-lucide-message-circle');
    expect(wrapper.findComponent(RouterLinkStub).props('to')).toContain(
      '/accounts/1/conversations/123'
    );
  });

  it('renders answered and unanswered calls with the summary', () => {
    const answered = factory(
      make('call', { interactionId: 1, answered: true, summary: 'combinado' })
    );
    expect(answered.text()).toContain('Answered call');
    expect(answered.text()).toContain('combinado');
    expect(iconClasses(answered)).toContain('i-lucide-phone');
    const missed = factory(
      make('call', { interactionId: 2, answered: false, summary: null })
    );
    expect(missed.text()).toContain('Unanswered call');
    expect(iconClasses(missed)).toContain('i-lucide-phone-missed');
  });

  it('renders a note', () => {
    const wrapper = factory(make('note', { interactionId: 3, summary: 'oi' }));
    expect(wrapper.text()).toContain('Note');
    expect(wrapper.text()).toContain('oi');
    expect(iconClasses(wrapper)).toContain('i-lucide-sticky-note');
  });

  it('renders the temperature change with labels and note', () => {
    const wrapper = factory(
      make('temperature_change', {
        from: 'quente',
        to: 'morno',
        note: 'esfriou',
      })
    );
    expect(wrapper.text()).toContain('from Hot to Warm');
    expect(wrapper.text()).toContain('esfriou');
    expect(iconClasses(wrapper)).toContain('i-lucide-thermometer');
  });

  it('renders a first temperature and a removed one', () => {
    expect(
      factory(make('temperature_change', { from: null, to: 'frio' })).text()
    ).toContain('set to Cold');
    expect(
      factory(make('temperature_change', { from: 'frio', to: null })).text()
    ).toContain('from Cold to No temperature');
  });

  it('renders assignment started and closed with role and front', () => {
    const started = factory(
      make(
        'assignment_change',
        { action: 'started', role: { id: 1, name: 'Lider' } },
        { front: { id: 10, name: 'Campo' } }
      )
    );
    expect(started.text()).toContain('Assignment started');
    expect(started.text()).toContain('Lider');
    expect(started.text()).toContain('Campo');
    expect(iconClasses(started)).toContain('i-lucide-user-round-check');
    const closed = factory(
      make('assignment_change', { action: 'closed', role: null })
    );
    expect(closed.text()).toContain('Assignment closed');
    expect(iconClasses(closed)).toContain('i-lucide-user-round-x');
  });

  describe('edit', () => {
    const call = (overrides = {}) =>
      make(
        'call',
        { interactionId: 1, answered: true, summary: 'x' },
        overrides
      );
    const hasEdit = wrapper =>
      wrapper.find('[data-test="event-edit"]').exists();

    it('shows for the author within 24h', () => {
      expect(hasEdit(factory(call()))).toBe(true);
    });

    it('hides for another user', () => {
      expect(hasEdit(factory(call(), { currentUserId: 9 }))).toBe(false);
    });

    it('hides after 24h', () => {
      expect(
        hasEdit(factory(call({ occurredAt: '2026-11-15T11:59:00Z' })))
      ).toBe(false);
    });

    it('never shows for other types', () => {
      const event = make('temperature_change', { from: null, to: 'frio' });
      expect(hasEdit(factory(event))).toBe(false);
    });

    it('emits the edited summary', async () => {
      const wrapper = factory(call());
      await wrapper.find('[data-test="event-edit"]').trigger('click');
      await wrapper
        .find('[data-test="event-edit-summary"] textarea')
        .setValue('novo');
      await wrapper.find('[data-test="event-edit-save"]').trigger('click');
      expect(wrapper.emitted('save')[0][0]).toEqual({
        interactionId: 1,
        summary: 'novo',
        answered: true,
      });
    });
  });
});
