import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import Index from '../Index.vue';
import MessageApi from 'dashboard/api/inbox/message.js';

const dispatch = vi.fn();

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/useTranslations', () => ({
  useTranslations: () => ({
    hasTranslations: ref(false),
    translationContent: ref(''),
  }),
}));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: k => k }) }));
vi.mock('dashboard/api/inbox/message.js', () => ({
  default: {
    approveAiSuggestion: vi.fn(),
    rejectAiSuggestion: vi.fn(),
  },
}));
vi.mock('../../../provider.js', () => ({
  useMessageContext: () => ({
    id: ref(55),
    conversationId: ref(9),
    content: ref('sugestao'),
    attachments: ref([]),
    contentAttributes: ref({ aiSuggestionId: 's1' }),
    messageType: ref(1),
    isPrivate: ref(true),
  }),
}));

const NextButtonStub = {
  props: ['label'],
  template: '<button :data-label="label" @click="$emit(\'click\')" />',
};

const mountComponent = () =>
  mount(Index, {
    global: {
      mocks: { $t: k => k },
      stubs: {
        BaseBubble: { template: '<div><slot /></div>' },
        FormattedContent: true,
        AttachmentChips: true,
        TranslationToggle: true,
        NextButton: NextButtonStub,
      },
    },
  });

describe('Text bubble AI suggestion actions', () => {
  beforeEach(() => {
    dispatch.mockClear();
    vi.clearAllMocks();
  });

  it('removes the message from the store when approve returns already_resolved', async () => {
    MessageApi.approveAiSuggestion.mockResolvedValue({
      data: { already_resolved: true },
    });
    const wrapper = mountComponent();
    await wrapper
      .find('[data-label="CONVERSATION.PRIVATE_NOTE.APPROVE_SUGGESTION"]')
      .trigger('click');
    await flushPromises();
    expect(dispatch).toHaveBeenCalledWith('removeMessage', {
      conversationId: 9,
      messageId: 55,
    });
  });

  it('removes the message from the store when reject returns already_resolved', async () => {
    MessageApi.rejectAiSuggestion.mockResolvedValue({
      data: { already_resolved: true },
    });
    const wrapper = mountComponent();
    await wrapper
      .find('[data-label="CONVERSATION.PRIVATE_NOTE.REJECT_SUGGESTION"]')
      .trigger('click');
    await flushPromises();
    expect(dispatch).toHaveBeenCalledWith('removeMessage', {
      conversationId: 9,
      messageId: 55,
    });
  });

  it('does not touch the store on a normal approve response', async () => {
    MessageApi.approveAiSuggestion.mockResolvedValue({
      data: { content_attributes: { ai_suggestion_status: 'approved' } },
    });
    const wrapper = mountComponent();
    await wrapper
      .find('[data-label="CONVERSATION.PRIVATE_NOTE.APPROVE_SUGGESTION"]')
      .trigger('click');
    await flushPromises();
    expect(dispatch).not.toHaveBeenCalled();
  });
});
