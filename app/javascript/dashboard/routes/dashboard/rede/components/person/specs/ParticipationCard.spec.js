import { mount } from '@vue/test-utils';
import ParticipationCard from '../ParticipationCard.vue';

const fronts = [
  { id: 10, name: 'Campo', status: 'active', hasTemperature: true },
  { id: 11, name: 'Digital', status: 'active', hasTemperature: false },
  { id: 12, name: 'Antiga', status: 'closed', hasTemperature: true },
];

const base = {
  id: 7,
  status: 'active',
  project: {
    id: 2,
    name: 'PE',
    color: '#ff0000',
    status: 'active',
    hasFronts: true,
  },
  responsible: { id: 9, name: 'Saiu' },
  referredBy: { contact: null, text: null },
  nextStep: 'ligar',
  lastContactAt: null,
  assignments: [
    {
      id: 1,
      front: { id: 10, name: 'Campo' },
      role: null,
      superior: null,
      temperature: 'quente',
    },
  ],
  projectTemperature: null,
  frontPending: false,
};

const factory = (participation = {}, props = {}) =>
  mount(ParticipationCard, {
    props: {
      participation: { ...base, ...participation },
      fronts,
      roles: [],
      responsibles: [{ id: 5, name: 'Bia' }],
      ...props,
    },
  });

describe('ParticipationCard', () => {
  it('shows the picker only for fronts with temperature', () => {
    const wrapper = factory({
      assignments: [
        ...base.assignments,
        {
          id: 2,
          front: { id: 11, name: 'Digital' },
          role: null,
          superior: null,
          temperature: null,
        },
      ],
    });
    expect(wrapper.findAll('[data-test="temperature-select"]')).toHaveLength(1);
  });

  it('lists a responsible who left the project until replaced', () => {
    const labels = factory()
      .findAll('[data-test="responsible-select"] option')
      .map(option => option.text());
    expect(labels).toContain('Saiu (outside the project)');
    expect(labels).toContain('Bia');
  });

  it('saves the next step on blur only when changed', async () => {
    const wrapper = factory();
    const input = wrapper.find('input[data-test="next-step"]');
    await input.trigger('blur');
    expect(wrapper.emitted('updateParticipation')).toBeUndefined();
    await input.setValue('visitar');
    await input.trigger('blur');
    expect(wrapper.emitted('updateParticipation')[0][0]).toEqual({
      nextStep: 'visitar',
    });
  });

  it('puts the project temperature in the block when there are no fronts', () => {
    const wrapper = factory({
      project: { ...base.project, hasFronts: false },
      assignments: [],
      projectTemperature: 'frio',
    });
    expect(wrapper.find('[data-test="project-temperature"]').text()).toContain(
      'Cold'
    );
  });

  it('defines the front of a pending participation by creating the assignment', async () => {
    const wrapper = factory({ assignments: [], frontPending: true });
    expect(wrapper.find('[data-test="front-pending"]').text()).toContain(
      'Front to be defined'
    );
    await wrapper.find('[data-test="define-front"]').trigger('click');
    await wrapper.find('[data-test="new-front"] select').setValue('10');
    await wrapper.find('[data-test="submit-assignment"]').trigger('click');
    expect(wrapper.emitted('createAssignment')[0][0]).toEqual({
      frontId: 10,
      roleId: undefined,
    });
  });

  it('only offers active fronts without an active assignment', async () => {
    const wrapper = factory();
    await wrapper.find('[data-test="add-assignment"]').trigger('click');
    const labels = wrapper
      .findAll('[data-test="new-front"] option')
      .map(option => option.text());
    expect(labels).toContain('Digital');
    expect(labels).not.toContain('Campo');
    expect(labels).not.toContain('Antiga');
  });

  it('dims a closed participation and removes the controls', () => {
    const wrapper = factory({ status: 'closed' });
    expect(wrapper.find('[data-test="closed-label"]').text()).toBe('Closed');
    expect(wrapper.classes()).toContain('opacity-60');
    expect(wrapper.find('[data-test="add-assignment"]').exists()).toBe(false);
    expect(wrapper.find('[data-test="next-step"]').exists()).toBe(false);
    expect(wrapper.find('[data-test="close-assignment"]').exists()).toBe(false);
  });

  it('keeps next step and responsible editable in a closed project', () => {
    const wrapper = factory({ project: { ...base.project, status: 'closed' } });
    expect(wrapper.find('[data-test="next-step"]').exists()).toBe(true);
    expect(wrapper.find('[data-test="responsible-select"]').exists()).toBe(
      true
    );
    expect(wrapper.find('[data-test="add-assignment"]').exists()).toBe(false);
    expect(wrapper.find('[data-test="temperature-select"]').exists()).toBe(
      false
    );
  });
});
