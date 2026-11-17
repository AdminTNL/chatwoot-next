import { mount } from '@vue/test-utils';
import DuplicatePair from '../DuplicatePair.vue';

const pair = {
  projectId: 1,
  contactA: {
    id: 1,
    name: 'Ana Souza',
    phoneNumber: '+5581999990000',
    city: 'Recife',
  },
  contactB: {
    id: 2,
    name: 'Ana S.',
    phoneNumber: '+558199990000',
    city: null,
  },
};

describe('DuplicatePair', () => {
  it('shows both people side by side', () => {
    const wrapper = mount(DuplicatePair, { props: { pair } });
    expect(wrapper.text()).toContain('Ana Souza');
    expect(wrapper.text()).toContain('Ana S.');
    expect(wrapper.text()).toContain('+5581999990000');
    expect(wrapper.text()).toContain('Recife');
  });

  it('emits dismiss with the pair', async () => {
    const wrapper = mount(DuplicatePair, { props: { pair } });
    await wrapper.find('[data-test="dismiss"]').trigger('click');
    expect(wrapper.emitted('dismiss')[0]).toEqual([pair]);
  });

  it('emits merge with the pair', async () => {
    const wrapper = mount(DuplicatePair, { props: { pair } });
    await wrapper.find('[data-test="merge"]').trigger('click');
    expect(wrapper.emitted('merge')[0]).toEqual([pair]);
  });

  it('disables the actions while busy', () => {
    const wrapper = mount(DuplicatePair, { props: { pair, busy: true } });
    expect(
      wrapper.find('[data-test="merge"]').attributes('disabled')
    ).toBeDefined();
    expect(
      wrapper.find('[data-test="dismiss"]').attributes('disabled')
    ).toBeDefined();
  });
});
