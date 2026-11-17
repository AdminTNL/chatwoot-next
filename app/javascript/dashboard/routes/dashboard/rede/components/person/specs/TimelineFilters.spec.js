import { mount } from '@vue/test-utils';
import TimelineFilters from '../TimelineFilters.vue';
import { buildTimelineParams } from '../timelineFilters';

const projects = [
  { id: 2, name: 'PE' },
  { id: 3, name: 'PA' },
];

const factory = (modelValue = {}) =>
  mount(TimelineFilters, { props: { modelValue, projects } });

const last = wrapper => wrapper.emitted('update:modelValue').at(-1)[0];

describe('TimelineFilters', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-11-16T12:00:00Z'));
  });
  afterEach(() => vi.useRealTimers());

  it.each([
    ['7', '2026-11-09'],
    ['30', '2026-10-17'],
    ['90', '2026-08-18'],
  ])('shortcut of %s days sets from and to', async (days, from) => {
    const wrapper = factory();
    await wrapper.find(`[data-test="period-${days}"]`).trigger('click');
    expect(last(wrapper)).toMatchObject({ from, to: '2026-11-16' });
  });

  it('toggles types', async () => {
    const wrapper = factory({ types: ['call'] });
    await wrapper.find('[data-test="type-note"]').trigger('click');
    expect(last(wrapper).types).toEqual(['call', 'note']);
    const other = factory({ types: ['call'] });
    await other.find('[data-test="type-call"]').trigger('click');
    expect(last(other).types).toEqual([]);
  });

  it('labels the five types', () => {
    const text = factory().text();
    ['Conversation', 'Call', 'Note', 'Temperature', 'Assignment'].forEach(
      label => expect(text).toContain(label)
    );
  });

  it('emits the project and the dates', async () => {
    const wrapper = factory();
    await wrapper.find('[data-test="filter-project"] select').setValue('3');
    expect(last(wrapper).projectId).toBe(3);
    await wrapper.find('input[data-test="filter-from"]').setValue('2026-11-01');
    expect(last(wrapper).from).toBe('2026-11-01');
  });

  it('does not emit an inverted range', async () => {
    const wrapper = factory({ from: '2026-11-10' });
    await wrapper.find('input[data-test="filter-to"]').setValue('2026-11-01');
    expect(wrapper.emitted('update:modelValue')).toBeUndefined();
    expect(wrapper.text()).toContain(
      'The start date must be before the end date.'
    );
  });

  it('builds API params skipping empty filters', () => {
    expect(buildTimelineParams({})).toEqual({});
    expect(
      buildTimelineParams({
        projectId: 2,
        from: '2026-11-09',
        to: '',
        types: ['call'],
      })
    ).toEqual({ project_id: 2, from: '2026-11-09', types: ['call'] });
  });
});
