import { mount } from '@vue/test-utils';
import AssignmentRow from '../AssignmentRow.vue';

const assignment = {
  id: 4,
  front: { id: 10, name: 'Campo' },
  role: { id: 7, name: 'Lider' },
  superior: { id: 3, name: 'Carlos' },
  temperature: 'quente',
};
const roles = [
  { id: 7, name: 'Lider' },
  { id: 8, name: 'Apoio' },
];

const factory = (props = {}) =>
  mount(AssignmentRow, {
    props: { assignment, roles, hasTemperature: true, ...props },
  });

describe('AssignmentRow', () => {
  it('shows the temperature picker only for a front with temperature', () => {
    expect(factory().find('[data-test="temperature-select"]').exists()).toBe(
      true
    );
    const wrapper = factory({
      hasTemperature: false,
      assignment: { ...assignment, temperature: null },
    });
    expect(wrapper.find('[data-test="temperature-select"]').exists()).toBe(
      false
    );
    expect(wrapper.text()).toContain('Campo');
  });

  it('forwards the picker value with the front id', async () => {
    const wrapper = factory();
    await wrapper
      .find('[data-test="temperature-select"] select')
      .setValue('frio');
    await wrapper.find('[data-test="temperature-save"]').trigger('click');
    expect(wrapper.emitted('setTemperature')[0][0]).toEqual({
      frontId: 10,
      level: 'frio',
      note: null,
    });
  });

  it('emits the role change and the close action', async () => {
    const wrapper = factory();
    await wrapper.find('[data-test="role-select"] select').setValue('8');
    expect(wrapper.emitted('update')[0][0]).toEqual({ roleId: 8 });
    await wrapper.find('[data-test="close-assignment"]').trigger('click');
    expect(wrapper.emitted('close')).toHaveLength(1);
  });

  it('has no controls when readonly', () => {
    const wrapper = factory({ readonly: true });
    expect(wrapper.find('[data-test="close-assignment"]').exists()).toBe(false);
    expect(wrapper.find('[data-test="temperature-select"]').exists()).toBe(
      false
    );
    expect(wrapper.find('[data-test="role-select"]').exists()).toBe(false);
    expect(wrapper.text()).toContain('Lider');
    expect(wrapper.text()).toContain('Hot');
  });
});
