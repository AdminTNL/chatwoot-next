import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import TimeAgo from '../TimeAgo.vue';

const unix = (...args) => Date.UTC(...args) / 1000;

describe('TimeAgo.vue', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(Date.UTC(2023, 4, 5, 23, 0)));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  const mountTimeAgo = props =>
    mount(TimeAgo, {
      props: {
        lastActivityTimestamp: unix(2023, 4, 5, 22, 0),
        conversationId: 1,
        ...props,
      },
    });

  it('shows only the last activity, without the created-at part', () => {
    const wrapper = mountTimeAgo();
    expect(wrapper.text()).not.toContain('•');
    expect(wrapper.text()).not.toContain('mo');
  });

  it('shows the date for activities older than yesterday', () => {
    const wrapper = mountTimeAgo({
      lastActivityTimestamp: unix(2023, 4, 1, 9, 0),
    });
    expect(wrapper.text()).toEqual('05/01/2023');
  });

  it('never schedules the refresh past midnight', () => {
    // Activity 3 days ago: the old rule would wait 24h.
    const wrapper = mountTimeAgo({
      lastActivityTimestamp: unix(2023, 4, 2, 9, 0),
    });
    // 23:00 UTC -> midnight is 1h away (+1s margin)
    expect(wrapper.vm.refreshTime()).toBeLessThanOrEqual(60 * 60 * 1000 + 1000);
  });

  it('switches to "Yesterday" after midnight', async () => {
    const wrapper = mountTimeAgo();
    expect(wrapper.text()).not.toEqual('Yesterday');
    vi.advanceTimersByTime(60 * 60 * 1000 + 1000);
    await nextTick();
    expect(wrapper.text()).toEqual('Yesterday');
  });

  it('shows only the localized last activity date and time in the tooltip', () => {
    const wrapper = mountTimeAgo();
    expect(wrapper.vm.tooltipText).toContain('Last activity:');
    expect(wrapper.vm.tooltipText).toContain('05/05/2023');
    expect(wrapper.vm.tooltipText).not.toContain('Created');
    expect(wrapper.vm.tooltipText).not.toContain('ago');
  });

  it('uses the current day when a new activity arrives after a delayed timer', async () => {
    const wrapper = mountTimeAgo();
    // Next day, but the midnight timer has not run yet (background tab, sleep).
    vi.setSystemTime(new Date(Date.UTC(2023, 4, 6, 9, 0)));
    await wrapper.setProps({ lastActivityTimestamp: unix(2023, 4, 6, 8, 30) });
    expect(wrapper.text()).toContain('08:30');
  });

  it('only wakes up right after midnight', () => {
    const wrapper = mountTimeAgo();
    // 23:00 UTC with activity 1h ago: next wake-up is midnight + 1s.
    expect(wrapper.vm.refreshTime()).toEqual(60 * 60 * 1000 + 1000);
  });
});
