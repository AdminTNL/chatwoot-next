<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { frontendURL } from 'dashboard/helper/URLHelper';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { getTemperature } from '../../helpers/temperature';
import ProjectBadge from '../people/ProjectBadge.vue';

// Um evento do histórico: ícone, texto por tipo e, em ligação e nota do
// próprio autor com menos de 24 h, a edição.
const props = defineProps({
  event: { type: Object, required: true },
  currentUserId: { type: Number, default: null },
  accountId: { type: Number, default: null },
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['save']);

const { t, locale } = useI18n();

const EDIT_WINDOW_MS = 24 * 60 * 60 * 1000;

const ICONS = {
  conversation: 'i-lucide-message-circle',
  note: 'i-lucide-sticky-note',
  temperature_change: 'i-lucide-thermometer',
};

const data = computed(() => props.event.data || {});

const icon = computed(() => {
  const { type } = props.event;
  if (type === 'call') {
    return data.value.answered ? 'i-lucide-phone' : 'i-lucide-phone-missed';
  }
  if (type === 'assignment_change') {
    return data.value.action === 'closed'
      ? 'i-lucide-user-round-x'
      : 'i-lucide-user-round-check';
  }
  return ICONS[type] || 'i-lucide-circle';
});

const levelLabel = level => t(getTemperature(level).labelKey);

const title = computed(() => {
  const { type } = props.event;
  if (type === 'conversation') {
    return t('REDE.PERSON.EVENTS.CONVERSATION', {
      id: data.value.displayId,
      inbox: data.value.inbox?.name || '',
    });
  }
  if (type === 'call') {
    return data.value.answered
      ? t('REDE.PERSON.EVENTS.CALL_ANSWERED')
      : t('REDE.PERSON.EVENTS.CALL_MISSED');
  }
  if (type === 'note') return t('REDE.PERSON.EVENTS.NOTE');
  if (type === 'temperature_change') {
    const to = levelLabel(data.value.to);
    return data.value.from
      ? t('REDE.PERSON.EVENTS.TEMPERATURE_CHANGED', {
          from: levelLabel(data.value.from),
          to,
        })
      : t('REDE.PERSON.EVENTS.TEMPERATURE_SET', { to });
  }
  return data.value.action === 'closed'
    ? t('REDE.PERSON.EVENTS.ASSIGNMENT_CLOSED')
    : t('REDE.PERSON.EVENTS.ASSIGNMENT_STARTED');
});

// Texto livre do evento: resumo da ligação/nota ou nota da temperatura.
const body = computed(() => data.value.summary || data.value.note || '');

const assignmentMeta = computed(() =>
  props.event.type === 'assignment_change'
    ? [data.value.role?.name, props.event.front?.name].filter(Boolean)
    : []
);

const conversationUrl = computed(() =>
  frontendURL(
    `accounts/${props.accountId}/conversations/${data.value.displayId}`
  )
);

const when = computed(() =>
  new Date(props.event.occurredAt).toLocaleString(
    locale.value.replace('_', '-')
  )
);

const isInteraction = computed(() =>
  ['call', 'note'].includes(props.event.type)
);
// A janela real da API conta da criação do registro; aqui usamos a data do
// evento. Se a API recusar, a tela mostra a mensagem dela.
const canEdit = computed(
  () =>
    isInteraction.value &&
    props.currentUserId !== null &&
    props.event.author?.id === props.currentUserId &&
    Date.now() - new Date(props.event.occurredAt).getTime() < EDIT_WINDOW_MS
);

const editing = ref(false);
const summary = ref('');
const answered = ref('no');

const startEdit = () => {
  summary.value = data.value.summary || '';
  answered.value = data.value.answered ? 'yes' : 'no';
  editing.value = true;
};

const save = () => {
  const payload = {
    interactionId: data.value.interactionId,
    summary: summary.value.trim(),
  };
  if (props.event.type === 'call') payload.answered = answered.value === 'yes';
  emit('save', payload);
};

// Depois de salvar, a lista recarrega e o evento chega novo: fecha a edição.
watch(
  () => props.event,
  () => {
    editing.value = false;
  }
);
</script>

<template>
  <li class="flex gap-3" data-test="timeline-event">
    <span
      class="flex items-center justify-center rounded-full size-8 shrink-0 bg-n-alpha-2 text-n-slate-11"
    >
      <span
        class="size-4"
        :class="icon"
        data-test="event-icon"
        aria-hidden="true"
      />
    </span>
    <div class="flex flex-col flex-1 min-w-0 gap-1">
      <div class="flex flex-wrap items-center gap-2">
        <router-link
          v-if="event.type === 'conversation'"
          :to="conversationUrl"
          class="text-sm font-medium text-n-brand hover:underline"
        >
          {{ title }}
        </router-link>
        <span v-else class="text-sm font-medium text-n-slate-12">
          {{ title }}
        </span>
        <span
          v-for="item in assignmentMeta"
          :key="item"
          class="text-sm text-n-slate-11"
        >
          {{ item }}
        </span>
        <ProjectBadge v-if="event.project" :project="event.project" />
        <span
          v-if="event.front && event.type !== 'assignment_change'"
          class="text-xs text-n-slate-11"
        >
          {{ event.front.name }}
        </span>
      </div>

      <div v-if="editing" class="flex flex-col gap-2">
        <Select
          v-if="event.type === 'call'"
          v-model="answered"
          data-test="event-edit-answered"
          :options="[
            { value: 'yes', label: t('REDE.PERSON.CALL.YES') },
            { value: 'no', label: t('REDE.PERSON.CALL.NO') },
          ]"
        />
        <TextArea
          v-model="summary"
          data-test="event-edit-summary"
          :max-length="2000"
        />
        <div class="flex gap-2">
          <Button
            data-test="event-edit-save"
            type="button"
            size="sm"
            :label="t('REDE.PERSON.EVENTS.SAVE')"
            :is-loading="isSaving"
            @click="save"
          />
          <Button
            type="button"
            size="sm"
            variant="ghost"
            color="slate"
            :label="t('REDE.PERSON.EVENTS.CANCEL')"
            @click="editing = false"
          />
        </div>
      </div>
      <p
        v-else-if="body"
        class="mb-0 text-sm whitespace-pre-line text-n-slate-11"
      >
        {{ body }}
      </p>

      <div class="flex flex-wrap items-center gap-2 text-xs text-n-slate-11">
        <span>{{ when }}</span>
        <span v-if="event.author?.name">· {{ event.author.name }}</span>
        <button
          v-if="canEdit && !editing"
          type="button"
          class="text-n-brand hover:underline"
          data-test="event-edit"
          @click="startEdit"
        >
          {{ t('REDE.PERSON.EVENTS.EDIT') }}
        </button>
      </div>
    </div>
  </li>
</template>
