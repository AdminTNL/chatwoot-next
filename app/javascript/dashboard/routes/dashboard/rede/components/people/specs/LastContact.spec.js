import { mount } from '@vue/test-utils';
import LastContact from '../LastContact.vue';

const NOW = new Date('2026-11-16T12:00:00Z');
const daysAgo = days => new Date(NOW.getTime() - days * 86400000).toISOString();

describe('LastContact', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(NOW);
  });
  afterEach(() => {
    vi.useRealTimers();
  });

  it('shows a relative date, not red, for a recent contact', () => {
    const wrapper = mount(LastContact, { props: { value: daysAgo(2) } });
    expect(wrapper.text()).toMatch(/2 days ago/);
    expect(wrapper.classes()).not.toContain('text-n-ruby-11');
  });

  it('is red when the contact is 9 days old', () => {
    const wrapper = mount(LastContact, { props: { value: daysAgo(9) } });
    expect(wrapper.text()).toMatch(/9 days ago/);
    expect(wrapper.classes()).toContain('text-n-ruby-11');
  });

  it('is not red at exactly 7 days', () => {
    const wrapper = mount(LastContact, { props: { value: daysAgo(7) } });
    expect(wrapper.classes()).not.toContain('text-n-ruby-11');
  });

  it('is red just past 7 days', () => {
    const value = new Date(NOW.getTime() - (7 * 86400000 + 3600000));
    const wrapper = mount(LastContact, {
      props: { value: value.toISOString() },
    });
    expect(wrapper.classes()).toContain('text-n-ruby-11');
  });

  it('shows Never in red when null', () => {
    const wrapper = mount(LastContact, { props: { value: null } });
    expect(wrapper.text()).toBe('Never');
    expect(wrapper.classes()).toContain('text-n-ruby-11');
  });

  it('exposes the full date in the tooltip', () => {
    const wrapper = mount(LastContact, { props: { value: daysAgo(2) } });
    expect(wrapper.attributes('title')).toBeTruthy();
  });
});
