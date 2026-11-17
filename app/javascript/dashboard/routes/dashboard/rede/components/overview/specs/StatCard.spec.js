import { mount } from '@vue/test-utils';
import StatCard from '../StatCard.vue';

const RouterLink = {
  props: ['to'],
  template: '<a :data-to="JSON.stringify(to)"><slot /></a>',
};

const mountCard = props =>
  mount(StatCard, {
    props: {
      label: 'People',
      value: 12,
      to: { name: 'rede_people' },
      ...props,
    },
    global: { stubs: { RouterLink } },
  });

describe('StatCard', () => {
  it('shows the label and the number', () => {
    const wrapper = mountCard();
    expect(wrapper.text()).toContain('People');
    expect(wrapper.text()).toContain('12');
  });

  it('links to the given destination', () => {
    const to = { name: 'rede_people', query: { no_contact_days: '7' } };
    const wrapper = mountCard({ to });
    expect(JSON.parse(wrapper.find('a').attributes('data-to'))).toEqual(to);
  });

  it('shows zero as a number', () => {
    expect(mountCard({ value: 0 }).text()).toContain('0');
  });

  it('highlights as alert only when asked and above zero', () => {
    expect(mountCard({ alert: true, value: 3 }).attributes('data-alert')).toBe(
      'true'
    );
    expect(mountCard({ alert: true, value: 0 }).attributes('data-alert')).toBe(
      'false'
    );
    expect(mountCard({ value: 3 }).attributes('data-alert')).toBe('false');
  });

  it('shows a skeleton instead of the number while loading', () => {
    const wrapper = mountCard({ loading: true });
    expect(wrapper.find('[data-test="skeleton"]').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('12');
  });
});
