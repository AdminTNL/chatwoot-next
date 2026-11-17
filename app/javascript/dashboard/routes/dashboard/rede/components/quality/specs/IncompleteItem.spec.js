import { mount } from '@vue/test-utils';
import IncompleteItem from '../IncompleteItem.vue';

const contact = { id: 7, name: 'Diego', phoneNumber: '+5581', city: null };
const build = kind =>
  mount(IncompleteItem, { props: { item: { kind, contact } } });

describe('IncompleteItem', () => {
  it.each(['missing_city', 'missing_phone', 'missing_name'])(
    'offers Complete for %s',
    async kind => {
      const wrapper = build(kind);
      expect(wrapper.find('[data-test="open-record"]').exists()).toBe(false);
      await wrapper.find('[data-test="complete"]').trigger('click');
      expect(wrapper.emitted('complete')[0]).toEqual([{ kind, contact }]);
    }
  );

  it('offers Open record for pending_front', async () => {
    const wrapper = build('pending_front');
    expect(wrapper.find('[data-test="complete"]').exists()).toBe(false);
    await wrapper.find('[data-test="open-record"]').trigger('click');
    expect(wrapper.emitted('openRecord')[0]).toEqual([7]);
  });

  it('describes the problem', () => {
    expect(build('missing_city').text()).toContain('No city');
    expect(build('missing_phone').text()).toContain('No phone');
    expect(build('missing_name').text()).toContain('No name');
    expect(build('pending_front').text()).toContain('Front to be defined');
  });
});
