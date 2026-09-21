import { ref, nextTick } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import ConversationHeader from '../ConversationHeader.vue';

const mockDispatch = vi.fn();
const mockUseAlert = vi.fn();
const currentChatRef = ref({});

vi.mock('vuex', async importOriginal => {
  const actual = await importOriginal();
  return {
    ...actual,
    useStore: () => ({
      dispatch: mockDispatch,
      getters: {
        get getSelectedChat() {
          return currentChatRef.value;
        },
        getCurrentAccountId: 1,
        'contacts/getContact': () => ({ name: 'Contato' }),
        'inboxes/getInbox': () => ({}),
        'inboxes/getInboxes': [],
      },
    }),
  };
});

vi.mock('vue-router', async importOriginal => {
  const actual = await importOriginal();
  return {
    ...actual,
    useRoute: () => ({ params: {}, name: 'inbox_conversation' }),
  };
});

vi.mock('dashboard/composables/useInbox', () => ({
  useInbox: () => ({ isAWebWidgetInbox: ref(false) }),
}));

vi.mock('dashboard/composables', async importOriginal => {
  const actual = await importOriginal();
  return { ...actual, useAlert: (...args) => mockUseAlert(...args) };
});

vi.mock('@vueuse/core', async importOriginal => {
  const actual = await importOriginal();
  return { ...actual, useElementSize: () => ({ width: ref(1000) }) };
});

const DialogStub = {
  name: 'Dialog',
  props: ['title', 'description', 'isLoading'],
  emits: ['confirm', 'close'],
  data: () => ({ isOpen: false }),
  methods: {
    open() {
      this.isOpen = true;
    },
    close() {
      this.isOpen = false;
    },
  },
  template: `<div v-if="isOpen" class="dialog-stub">
    <span class="dialog-description">{{ description }}</span>
    <button class="dialog-confirm" @click="$emit('confirm')" />
    <button class="dialog-cancel" @click="close" />
  </div>`,
};

const buildMessages = statuses =>
  statuses.map((status, index) => ({
    id: index + 1,
    content_attributes: {
      ai_suggestion_id: `sug-${index}`,
      ...(status ? { ai_suggestion_status: status } : {}),
    },
  }));

const mountHeader = (messages, showResolved = ref(false)) => {
  currentChatRef.value = { id: 42, status: 'open', messages };
  return mount(ConversationHeader, {
    props: {
      chat: { id: 42, meta: { sender: { id: 1 } }, messages },
    },
    global: {
      provide: { showResolvedAiSuggestions: showResolved },
      stubs: {
        BackButton: true,
        InboxName: true,
        MoreActions: true,
        Avatar: true,
        SLACardLabel: true,
        ConversationCallButton: true,
        Dialog: DialogStub,
        'fluent-icon': true,
      },
    },
  });
};

const eraserButton = wrapper =>
  wrapper.find('button[class*="rounded-md"] .i-lucide-eraser');
const sparklesButton = wrapper =>
  wrapper.find('button[class*="rounded-md"] .i-lucide-sparkles');

describe('ConversationHeader AI history', () => {
  beforeEach(() => {
    mockDispatch.mockReset();
    mockUseAlert.mockReset();
  });

  it('hides both the clear button and the toggle without AI notes', () => {
    const wrapper = mountHeader([{ id: 1, content_attributes: {} }]);
    expect(eraserButton(wrapper).exists()).toBe(false);
    expect(sparklesButton(wrapper).exists()).toBe(false);
  });

  it('shows only the clear button with a pending note', () => {
    const wrapper = mountHeader(buildMessages([undefined]));
    expect(eraserButton(wrapper).exists()).toBe(true);
    expect(sparklesButton(wrapper).exists()).toBe(false);
  });

  it.each(['approved', 'dismissed'])(
    'shows both the button and the toggle with a %s note',
    status => {
      const wrapper = mountHeader(buildMessages([status]));
      expect(eraserButton(wrapper).exists()).toBe(true);
      expect(sparklesButton(wrapper).exists()).toBe(true);
    }
  );

  const openAndConfirm = async wrapper => {
    await eraserButton(wrapper).element.closest('button').click();
    await nextTick();
    return wrapper.find('.dialog-stub');
  };

  it('opens the confirmation and does not dispatch on cancel', async () => {
    const wrapper = mountHeader(buildMessages(['approved']));
    const dialog = await openAndConfirm(wrapper);
    expect(dialog.exists()).toBe(true);
    expect(dialog.find('.dialog-description').text()).toBe(
      wrapper.vm.$t('CONVERSATION.CLEAR_AI_HISTORY.DESCRIPTION')
    );
    await wrapper.find('.dialog-cancel').trigger('click');
    expect(mockDispatch).not.toHaveBeenCalled();
  });

  it('dispatches clearAiHistory with the conversation id on confirm', async () => {
    mockDispatch.mockResolvedValue({
      messages_deleted: 2,
      suggestions_deleted: 1,
    });
    const wrapper = mountHeader(buildMessages(['approved']));
    await openAndConfirm(wrapper);
    await wrapper.find('.dialog-confirm').trigger('click');
    await flushPromises();
    expect(mockDispatch).toHaveBeenCalledWith('clearAiHistory', {
      conversationId: 42,
    });
  });

  it('shows the success alert and hides the button once notes are gone', async () => {
    mockDispatch.mockImplementation(async () => {
      currentChatRef.value = { ...currentChatRef.value, messages: [] };
      return { messages_deleted: 3, suggestions_deleted: 1 };
    });
    const wrapper = mountHeader(buildMessages(['approved']));
    await openAndConfirm(wrapper);
    await wrapper.find('.dialog-confirm').trigger('click');
    await flushPromises();
    expect(mockUseAlert).toHaveBeenCalledTimes(1);
    expect(mockUseAlert.mock.calls[0][0]).toBe(
      wrapper.vm.$t('CONVERSATION.CLEAR_AI_HISTORY.SUCCESS')
    );
    await nextTick();
    expect(eraserButton(wrapper).exists()).toBe(false);
  });

  it('shows the empty alert when nothing was deleted', async () => {
    mockDispatch.mockResolvedValue({
      messages_deleted: 0,
      suggestions_deleted: 0,
    });
    const wrapper = mountHeader(buildMessages([undefined]));
    await openAndConfirm(wrapper);
    await wrapper.find('.dialog-confirm').trigger('click');
    await flushPromises();
    expect(mockUseAlert).toHaveBeenCalledWith(
      wrapper.vm.$t('CONVERSATION.CLEAR_AI_HISTORY.SUCCESS_EMPTY')
    );
  });

  it('shows the not-linked alert on 422 "not linked" and keeps the notes', async () => {
    mockDispatch.mockRejectedValue({
      response: { status: 422, data: { error: 'Inbox is not linked to AI' } },
    });
    const wrapper = mountHeader(buildMessages([undefined]));
    await openAndConfirm(wrapper);
    await wrapper.find('.dialog-confirm').trigger('click');
    await flushPromises();
    expect(mockUseAlert).toHaveBeenCalledWith(
      wrapper.vm.$t('CONVERSATION.CLEAR_AI_HISTORY.ERROR_NOT_LINKED')
    );
    expect(eraserButton(wrapper).exists()).toBe(true);
  });

  it('shows the generic alert on other errors and keeps the notes', async () => {
    mockDispatch.mockRejectedValue(new Error('boom'));
    const wrapper = mountHeader(buildMessages([undefined]));
    await openAndConfirm(wrapper);
    await wrapper.find('.dialog-confirm').trigger('click');
    await flushPromises();
    expect(mockUseAlert).toHaveBeenCalledWith(
      wrapper.vm.$t('CONVERSATION.CLEAR_AI_HISTORY.ERROR')
    );
    expect(eraserButton(wrapper).exists()).toBe(true);
  });

  it('turns showResolvedAiSuggestions off when the last resolved note disappears', async () => {
    const showResolved = ref(true);
    const wrapper = mountHeader(buildMessages(['approved']), showResolved);
    expect(sparklesButton(wrapper).exists()).toBe(true);
    currentChatRef.value = {
      ...currentChatRef.value,
      messages: buildMessages([undefined]),
    };
    await nextTick();
    await nextTick();
    expect(showResolved.value).toBe(false);
    expect(sparklesButton(wrapper).exists()).toBe(false);
  });
});
