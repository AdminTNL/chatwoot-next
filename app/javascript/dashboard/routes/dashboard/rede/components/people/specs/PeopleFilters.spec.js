import { mount } from '@vue/test-utils';
import PeopleFilters from '../PeopleFilters.vue';

const options = {
  projects: [
    {
      id: 1,
      name: 'Mobiliza',
      color: '#ff0000',
      status: 'active',
      fronts: [
        { id: 10, name: 'Campo', status: 'active' },
        { id: 11, name: 'Rede', status: 'active' },
      ],
    },
    {
      id: 2,
      name: 'PE',
      color: '#00ff00',
      status: 'active',
      fronts: [{ id: 20, name: 'Digital', status: 'active' }],
    },
  ],
  responsibles: [{ id: 5, name: 'Bia' }],
};

const factory = (modelValue = {}) =>
  mount(PeopleFilters, { props: { modelValue, options } });

const lastEmit = wrapper => {
  const events = wrapper.emitted('update:modelValue');
  return events[events.length - 1][0];
};

describe('PeopleFilters', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });
  afterEach(() => {
    vi.useRealTimers();
  });

  it('emits project ids and drops the page', () => {
    const wrapper = factory({ page: 3, sort: 'name' });
    wrapper
      .findComponent('[data-test="filter-projects"]')
      .vm.$emit('update:modelValue', [1, 2]);
    expect(lastEmit(wrapper)).toEqual({ project_ids: [1, 2], sort: 'name' });
  });

  it('offers none options for front, temperature and responsible', () => {
    const wrapper = factory();
    const optionsOf = selector =>
      wrapper.findComponent(selector).props('options');
    expect(optionsOf('[data-test="filter-fronts"]')).toContainEqual({
      value: 'none',
      label: 'No front',
    });
    expect(optionsOf('[data-test="filter-temperatures"]')).toContainEqual({
      value: 'none',
      label: 'No temperature',
    });
    expect(optionsOf('[data-test="filter-responsibles"]')).toContainEqual({
      value: 'none',
      label: 'No responsible',
    });
  });

  it('groups front options by project and narrows to selected projects', () => {
    const wrapper = factory({ project_ids: [2] });
    const labels = wrapper
      .findComponent('[data-test="filter-fronts"]')
      .props('options')
      .map(option => option.label);
    expect(labels).toContain('PE · Digital');
    expect(labels).not.toContain('Mobiliza · Campo');
  });

  it('emits temperatures and responsibles', () => {
    const wrapper = factory();
    wrapper
      .findComponent('[data-test="filter-temperatures"]')
      .vm.$emit('update:modelValue', ['quente', 'none']);
    expect(lastEmit(wrapper)).toEqual({ temperatures: ['quente', 'none'] });
    wrapper
      .findComponent('[data-test="filter-responsibles"]')
      .vm.$emit('update:modelValue', [5, 'none']);
    expect(lastEmit(wrapper)).toEqual({ responsible_ids: [5, 'none'] });
  });

  it('emits the no contact days preset', async () => {
    const wrapper = factory();
    await wrapper.find('[data-test="filter-no-contact"] select').setValue('15');
    expect(lastEmit(wrapper)).toEqual({ no_contact_days: 15 });
  });

  it('accepts a custom number of days', async () => {
    const wrapper = factory();
    await wrapper
      .find('[data-test="filter-no-contact"] select')
      .setValue('custom');
    await wrapper.find('input[data-test="filter-custom-days"]').setValue('45');
    expect(lastEmit(wrapper)).toEqual({ no_contact_days: 45 });
  });

  it('toggles include closed projects', async () => {
    const wrapper = factory();
    await wrapper
      .find('input[data-test="filter-include-closed"]')
      .setValue(true);
    expect(lastEmit(wrapper)).toEqual({ include_closed: true });
  });

  it('debounces the search by 300 ms', async () => {
    const wrapper = factory();
    const input = wrapper.find('input[data-test="filter-search"]');
    await input.setValue('a');
    await input.setValue('an');
    await input.setValue('ana');
    vi.advanceTimersByTime(299);
    expect(wrapper.emitted('update:modelValue')).toBeUndefined();
    vi.advanceTimersByTime(1);
    expect(wrapper.emitted('update:modelValue')).toHaveLength(1);
    expect(lastEmit(wrapper)).toEqual({ q: 'ana' });
  });

  it('debounces the city too', async () => {
    const wrapper = factory();
    await wrapper.find('input[data-test="filter-city"]').setValue('Recife');
    vi.advanceTimersByTime(300);
    expect(lastEmit(wrapper)).toEqual({ city: 'Recife' });
  });

  it('shows the clear button only with filters and clears them keeping the sort', async () => {
    const empty = factory({ sort: 'name' });
    expect(empty.find('[data-test="filter-clear"]').exists()).toBe(false);

    const wrapper = factory({
      project_ids: [1],
      q: 'ana',
      temperatures: ['quente'],
      page: 2,
      sort: 'name',
    });
    await wrapper.find('[data-test="filter-clear"]').trigger('click');
    expect(lastEmit(wrapper)).toEqual({ sort: 'name' });
  });

  it('fills the inputs from the model value', () => {
    const wrapper = factory({ q: 'ana', city: 'Recife', no_contact_days: 30 });
    expect(wrapper.find('input[data-test="filter-search"]').element.value).toBe(
      'ana'
    );
    expect(wrapper.find('input[data-test="filter-city"]').element.value).toBe(
      'Recife'
    );
    expect(
      wrapper.find('[data-test="filter-no-contact"] select').element.value
    ).toBe('30');
  });
});
