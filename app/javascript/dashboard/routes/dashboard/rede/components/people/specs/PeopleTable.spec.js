import { mount, RouterLinkStub } from '@vue/test-utils';
import PeopleTable from '../PeopleTable.vue';

const baseRow = {
  rowKey: '1-2-3',
  contact: { id: 1, name: 'Ana', phoneNumber: '+5581999990000' },
  project: { id: 2, name: 'Mobiliza', color: '#ff0000', status: 'active' },
  front: { id: 10, name: 'Campo' },
  frontPending: false,
  role: { id: 1, name: 'Lider' },
  temperature: 'quente',
  responsible: { id: 5, name: 'Bia' },
  lastContactAt: null,
  nextStep: 'Ligar na segunda',
};

const factory = (rows, props = {}) =>
  mount(PeopleTable, {
    props: { rows, ...props },
    global: { stubs: { RouterLink: RouterLinkStub } },
  });

describe('PeopleTable', () => {
  it('colors the row by temperature and always shows the label', () => {
    const wrapper = factory([baseRow]);
    const row = wrapper.find('[data-test="people-row"]');
    expect(row.classes()).toContain('bg-n-amber-2');
    expect(row.text()).toContain('Hot');
  });

  it('uses the neutral background and the label without temperature', () => {
    const wrapper = factory([{ ...baseRow, temperature: null }]);
    const row = wrapper.find('[data-test="people-row"]');
    expect(row.classes()).toContain('bg-n-alpha-1');
    expect(row.text()).toContain('No temperature');
  });

  it('shows the pending front warning', () => {
    const wrapper = factory([{ ...baseRow, front: null, frontPending: true }]);
    expect(wrapper.find('[data-test="cell-front"]').text()).toBe(
      'Front to be defined'
    );
  });

  it('shows a dash for a project without fronts', () => {
    const wrapper = factory([{ ...baseRow, front: null }]);
    expect(wrapper.find('[data-test="cell-front"]').text()).toBe('—');
  });

  it('marks a closed front', () => {
    const projects = [
      { id: 2, fronts: [{ id: 10, name: 'Campo', status: 'closed' }] },
    ];
    const wrapper = factory([baseRow], { projects });
    expect(wrapper.find('[data-test="cell-front"]').text()).toBe(
      'Campo (closed)'
    );
  });

  it('uses the phone as the title when the contact has no name', () => {
    const wrapper = factory([
      { ...baseRow, contact: { id: 1, name: '', phoneNumber: '+5581' } },
    ]);
    expect(wrapper.findComponent(RouterLinkStub).text()).toBe('+5581');
  });

  it('links the person to the person page', () => {
    const wrapper = factory([baseRow]);
    expect(wrapper.findComponent(RouterLinkStub).props('to')).toEqual({
      name: 'rede_person',
      params: { contactId: 1 },
    });
  });

  it('cycles the sort from the header', async () => {
    const wrapper = factory([baseRow], { sort: '' });
    await wrapper.find('[data-test="sort-name"]').trigger('click');
    expect(wrapper.emitted('update:sort')[0]).toEqual(['name']);

    await wrapper.setProps({ sort: 'name' });
    await wrapper.find('[data-test="sort-name"]').trigger('click');
    expect(wrapper.emitted('update:sort')[1]).toEqual(['-name']);

    await wrapper.setProps({ sort: '-name' });
    await wrapper.find('[data-test="sort-name"]').trigger('click');
    expect(wrapper.emitted('update:sort')[2]).toEqual(['']);
  });
});
