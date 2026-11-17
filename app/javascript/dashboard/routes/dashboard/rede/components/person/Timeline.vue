<script setup>
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { timelineEventKey } from 'dashboard/stores/rede/person';
import TimelineEvent from './TimelineEvent.vue';

// Lista vertical, do mais novo para o mais antigo, com "Carregar mais".
defineProps({
  events: { type: Array, default: () => [] },
  hasMore: { type: Boolean, default: false },
  isLoading: { type: Boolean, default: false },
  isSaving: { type: Boolean, default: false },
  currentUserId: { type: Number, default: null },
  accountId: { type: Number, default: null },
});

const emit = defineEmits(['load-more', 'save']);

const { t } = useI18n();
</script>

<template>
  <div class="flex flex-col gap-4">
    <ul v-if="events.length" class="flex flex-col gap-5 m-0 list-none p-0">
      <TimelineEvent
        v-for="event in events"
        :key="timelineEventKey(event)"
        :event="event"
        :current-user-id="currentUserId"
        :account-id="accountId"
        :is-saving="isSaving"
        @save="payload => emit('save', payload)"
      />
    </ul>
    <p
      v-else-if="!isLoading"
      class="mb-0 text-sm text-n-slate-11"
      data-test="timeline-empty"
    >
      {{ t('REDE.PERSON.TIMELINE.EMPTY') }}
    </p>
    <div v-if="isLoading" class="flex justify-center py-2">
      <Spinner />
    </div>
    <Button
      v-if="hasMore && !isLoading"
      data-test="timeline-load-more"
      type="button"
      variant="faded"
      color="slate"
      class="self-center"
      :label="t('REDE.PERSON.TIMELINE.LOAD_MORE')"
      @click="emit('load-more')"
    />
  </div>
</template>
