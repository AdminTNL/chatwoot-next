<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import BaseBubble from 'next/message/bubbles/Base.vue';
import FormattedContent from './FormattedContent.vue';
import AttachmentChips from 'next/message/chips/AttachmentChips.vue';
import TranslationToggle from 'dashboard/components-next/message/TranslationToggle.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { MESSAGE_TYPES } from '../../constants';
import { useMessageContext } from '../../provider.js';
import { useTranslations } from 'dashboard/composables/useTranslations';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import MessageApi from 'dashboard/api/inbox/message.js';

const { t } = useI18n();
const {
  id,
  conversationId,
  content,
  attachments,
  contentAttributes,
  messageType,
  isPrivate,
} = useMessageContext();

const { hasTranslations, translationContent } =
  useTranslations(contentAttributes);

const renderOriginal = ref(false);

const renderContent = computed(() => {
  if (renderOriginal.value) {
    return content.value;
  }

  if (hasTranslations.value) {
    return translationContent.value;
  }

  return content.value;
});

const isTemplate = computed(() => {
  return messageType.value === MESSAGE_TYPES.TEMPLATE;
});

const isEmpty = computed(() => {
  return !content.value && !attachments.value?.length;
});

const handleSeeOriginal = () => {
  renderOriginal.value = !renderOriginal.value;
};

const aiSuggestionId = computed(() => contentAttributes.value?.aiSuggestionId);
const aiSuggestionStatus = computed(
  () => contentAttributes.value?.aiSuggestionStatus
);
const isPendingAiSuggestion = computed(
  () => isPrivate.value && !!aiSuggestionId.value && !aiSuggestionStatus.value
);
const isProcessingAiSuggestion = ref(false);

const handleApproveAiSuggestion = async () => {
  isProcessingAiSuggestion.value = true;
  try {
    await MessageApi.approveAiSuggestion(conversationId.value, id.value);
  } catch (error) {
    useAlert(t('CONVERSATION.PRIVATE_NOTE.APPROVE_ERROR'));
  } finally {
    isProcessingAiSuggestion.value = false;
  }
};

const handleRejectAiSuggestion = async () => {
  isProcessingAiSuggestion.value = true;
  try {
    await MessageApi.rejectAiSuggestion(conversationId.value, id.value);
  } catch (error) {
    useAlert(t('CONVERSATION.PRIVATE_NOTE.REJECT_ERROR'));
  } finally {
    isProcessingAiSuggestion.value = false;
  }
};

const handleCopyAiSuggestion = async () => {
  try {
    await copyTextToClipboard(content.value);
    useAlert(t('CONVERSATION.PRIVATE_NOTE.COPY_SUCCESS'));
  } catch (error) {
    // clipboard write failed silently, no user-facing state to roll back
  }
};
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="text">
    <div class="gap-3 flex flex-col">
      <span v-if="isEmpty" class="text-n-slate-11">
        {{ $t('CONVERSATION.NO_CONTENT') }}
      </span>
      <FormattedContent v-if="renderContent" :content="renderContent" />
      <TranslationToggle
        v-if="hasTranslations"
        class="-mt-3"
        :showing-original="renderOriginal"
        @toggle="handleSeeOriginal"
      />
      <AttachmentChips :attachments="attachments" class="gap-2" />
      <div v-if="aiSuggestionId" class="flex flex-wrap gap-2">
        <NextButton
          v-if="isPendingAiSuggestion"
          size="sm"
          color="teal"
          icon="i-lucide-check"
          :label="$t('CONVERSATION.PRIVATE_NOTE.APPROVE_SUGGESTION')"
          :is-loading="isProcessingAiSuggestion"
          :disabled="isProcessingAiSuggestion"
          @click="handleApproveAiSuggestion"
        />
        <NextButton
          v-if="isPendingAiSuggestion"
          size="sm"
          variant="faded"
          color="ruby"
          icon="i-lucide-x"
          :label="$t('CONVERSATION.PRIVATE_NOTE.REJECT_SUGGESTION')"
          :is-loading="isProcessingAiSuggestion"
          :disabled="isProcessingAiSuggestion"
          @click="handleRejectAiSuggestion"
        />
        <NextButton
          size="sm"
          variant="faded"
          color="slate"
          icon="i-lucide-copy"
          :label="$t('CONVERSATION.PRIVATE_NOTE.COPY_SUGGESTION')"
          @click="handleCopyAiSuggestion"
        />
      </div>
      <template v-if="isTemplate">
        <div
          v-if="contentAttributes.submittedEmail"
          class="px-2 py-1 rounded-lg bg-n-alpha-3"
        >
          {{ contentAttributes.submittedEmail }}
        </div>
      </template>
    </div>
  </BaseBubble>
</template>

<style>
p:last-child {
  margin-bottom: 0;
}
</style>
