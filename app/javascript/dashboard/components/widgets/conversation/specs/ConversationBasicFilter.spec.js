import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import ConversationBasicFilter from '../ConversationBasicFilter.vue';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';

// Follows the module-mocking pattern used elsewhere in this codebase for
// components built on `dashboard/composables/store.js` (see
// composables/spec/useUISettings.spec.js) rather than trying to inject a
// fake `$store` onto the component instance.
const mockDispatch = vi.fn();
const mockUpdateUISettings = vi.fn();
const chatSortFilterMock = ref('last_activity_at_desc');

vi.mock('dashboard/composables/store.js', () => ({
  useMapGetter: () => chatSortFilterMock,
  useStore: () => ({ dispatch: mockDispatch }),
}));

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ updateUISettings: mockUpdateUISettings }),
}));

// `showActionsDropdown` (the `[state, toggle] = useToggle()` from
// @vueuse/core) starts closed and only opens via a real click on the
// NextButton toggle. NextButton is globally stubbed in vitest.setup.js to a
// bare `<button><slot/></button>` that (unlike the real component) doesn't
// forward the `@click` listener, so there is no reliable DOM interaction
// left to open the dropdown in a test. Forcing `useToggle` to report "open"
// sidesteps that and lets these tests focus on what they actually care
// about: the dropdown's *content* once visible.
vi.mock('@vueuse/core', async importOriginal => {
  const actual = await importOriginal();
  return { ...actual, useToggle: () => [ref(true), vi.fn()] };
});

describe('ConversationBasicFilter', () => {
  beforeEach(() => {
    mockDispatch.mockClear();
    mockUpdateUISettings.mockClear();
  });

  const mountComponent = () =>
    mount(ConversationBasicFilter, {
      props: { isOnExpandedLayout: false },
      global: {
        mocks: { $t: key => key },
      },
    });

  it('shows only the "order by" select menu, with no status selector', () => {
    const wrapper = mountComponent();

    expect(wrapper.findAllComponents(SelectMenu)).toHaveLength(1);
    expect(wrapper.text()).not.toContain('CHAT_LIST.CHAT_SORT.STATUS');
    expect(wrapper.text()).toContain('CHAT_LIST.CHAT_SORT.ORDER_BY');
  });

  it('saveSelectedFilter only ever persists order_by, never status, to conversations_filter_by', async () => {
    const wrapper = mountComponent();

    const selectMenu = wrapper.findComponent(SelectMenu);
    await selectMenu.vm.$emit('update:modelValue', 'created_at_desc');

    expect(mockUpdateUISettings).toHaveBeenCalledWith({
      conversations_filter_by: { order_by: 'created_at_desc' },
    });
  });
});
