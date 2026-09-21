import { shallowMount } from '@vue/test-utils';
import ChatTypeTabs from '../ChatTypeTabs.vue';
import wootConstants from 'dashboard/constants/globals';

// `useKeyboardEvents` normally wires the `Alt+KeyN` shortcut through
// `document.addEventListener`/tinykeys (see useKeyboardEvents.spec.js for
// coverage of that plumbing). Here we only care about the cycling logic
// ChatTypeTabs hands to it, so we capture the `keyboardEvents` object the
// component passes in and invoke the action directly.
const keyboardEventsMock = vi.hoisted(() => ({ captured: null }));

vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(events => {
    keyboardEventsMock.captured = events;
  }),
}));

// Mirrors the order produced by ChatList.vue's `readStatusTabItems`
// (Object.values(wootConstants.READ_STATUS_TYPE)).
const READ_STATUS_TAB_ITEMS = [
  { key: wootConstants.READ_STATUS_TYPE.UNREAD, name: 'Unread', count: 1 },
  {
    key: wootConstants.READ_STATUS_TYPE.IN_PROGRESS,
    name: 'In progress',
    count: 2,
  },
  { key: wootConstants.READ_STATUS_TYPE.SNOOZED, name: 'Snoozed', count: 3 },
  { key: wootConstants.READ_STATUS_TYPE.RESOLVED, name: 'Resolved', count: 4 },
  { key: wootConstants.READ_STATUS_TYPE.ALL, name: 'All', count: 10 },
];

const mountComponent = activeTab =>
  shallowMount(ChatTypeTabs, {
    props: { items: READ_STATUS_TAB_ITEMS, activeTab },
  });

const triggerAltKeyN = () => keyboardEventsMock.captured['Alt+KeyN'].action();

describe('ChatTypeTabs', () => {
  beforeEach(() => {
    keyboardEventsMock.captured = null;
  });

  it('defaults the active tab to Unread', () => {
    const wrapper = shallowMount(ChatTypeTabs, {
      props: { items: READ_STATUS_TAB_ITEMS },
    });
    expect(wrapper.props('activeTab')).toBe(
      wootConstants.READ_STATUS_TYPE.UNREAD
    );
  });

  it('cycles from Unread to In progress on Alt+KeyN', () => {
    const wrapper = mountComponent(wootConstants.READ_STATUS_TYPE.UNREAD);
    triggerAltKeyN();
    expect(wrapper.emitted('chatTabChange')[0]).toEqual([
      wootConstants.READ_STATUS_TYPE.IN_PROGRESS,
    ]);
  });

  it('wraps around from All back to Unread on Alt+KeyN', () => {
    const wrapper = mountComponent(wootConstants.READ_STATUS_TYPE.ALL);
    triggerAltKeyN();
    expect(wrapper.emitted('chatTabChange')[0]).toEqual([
      wootConstants.READ_STATUS_TYPE.UNREAD,
    ]);
  });

  it('cycles through all 5 tabs in order, wrapping back to Unread', async () => {
    const order = [
      wootConstants.READ_STATUS_TYPE.UNREAD,
      wootConstants.READ_STATUS_TYPE.IN_PROGRESS,
      wootConstants.READ_STATUS_TYPE.SNOOZED,
      wootConstants.READ_STATUS_TYPE.RESOLVED,
      wootConstants.READ_STATUS_TYPE.ALL,
      wootConstants.READ_STATUS_TYPE.UNREAD,
    ];

    const wrapper = mountComponent(order[0]);
    for (let i = 1; i < order.length; i += 1) {
      triggerAltKeyN();
      const emittedEvents = wrapper.emitted('chatTabChange');
      const nextTab = emittedEvents[emittedEvents.length - 1][0];
      expect(nextTab).toBe(order[i]);
      // eslint-disable-next-line no-await-in-loop
      await wrapper.setProps({ activeTab: nextTab });
    }
  });
});
