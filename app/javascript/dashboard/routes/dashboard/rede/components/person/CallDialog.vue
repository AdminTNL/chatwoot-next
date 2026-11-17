<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { toDateTimeInput } from './timelineFilters';

// Registrar ligação. Não fala com a API: emite `submit` e quem abriu decide.
// "Quem ligou" é sempre o usuário logado (authorName), só para leitura.
// Reaproveitado na 018.
const props = defineProps({
  // Projetos em que dá para registrar (participação ativa), [{ id, name }].
  projects: { type: Array, default: () => [] },
  // Frentes ativas por projeto: { [projectId]: [{ id, name }] }.
  frontsByProject: { type: Object, default: () => ({}) },
  authorName: { type: String, default: '' },
  isLoading: { type: Boolean, default: false },
  errorMessage: { type: String, default: '' },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const dialogRef = ref(null);
const projectId = ref('');
const frontId = ref('');
const answered = ref('');
const occurredAt = ref('');
const summary = ref('');
const errors = ref({});

const projectOptions = computed(() =>
  props.projects.map(project => ({ value: project.id, label: project.name }))
);
const fronts = computed(() => props.frontsByProject[projectId.value] || []);
const frontOptions = computed(() => [
  { value: '', label: t('REDE.PERSON.CALL.FRONT_NONE') },
  ...fronts.value.map(front => ({ value: front.id, label: front.name })),
]);
const answeredOptions = computed(() => [
  { value: 'yes', label: t('REDE.PERSON.CALL.YES') },
  { value: 'no', label: t('REDE.PERSON.CALL.NO') },
]);

const reset = () => {
  projectId.value = props.projects.length === 1 ? props.projects[0].id : '';
  frontId.value = '';
  answered.value = '';
  occurredAt.value = toDateTimeInput(new Date());
  summary.value = '';
  errors.value = {};
};

const open = () => {
  reset();
  dialogRef.value?.open();
};
const close = () => dialogRef.value?.close();

const onProjectChange = value => {
  projectId.value = value;
  frontId.value = '';
};

const validate = () => {
  const found = {};
  if (!projectId.value) {
    found.project = t('REDE.PERSON.CALL.ERRORS.PROJECT_REQUIRED');
  }
  if (!answered.value) {
    found.answered = t('REDE.PERSON.CALL.ERRORS.ANSWERED_REQUIRED');
  }
  const date = new Date(occurredAt.value);
  if (!occurredAt.value || Number.isNaN(date.getTime())) {
    found.occurredAt = t('REDE.PERSON.CALL.ERRORS.DATE_REQUIRED');
  } else if (date.getTime() > Date.now()) {
    found.occurredAt = t('REDE.PERSON.CALL.ERRORS.FUTURE_DATE');
  }
  errors.value = found;
  return Object.keys(found).length === 0;
};

const submit = () => {
  if (!validate()) return;
  const payload = {
    projectId: Number(projectId.value),
    answered: answered.value === 'yes',
    occurredAt: new Date(occurredAt.value).toISOString(),
  };
  if (frontId.value) payload.frontId = Number(frontId.value);
  if (summary.value.trim()) payload.summary = summary.value.trim();
  emit('submit', payload);
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    overflow-y-auto
    :title="t('REDE.PERSON.CALL.TITLE')"
    :confirm-button-label="t('REDE.PERSON.CALL.CONFIRM')"
    :is-loading="isLoading"
    @confirm="submit"
  >
    <div class="flex flex-col gap-4">
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div class="flex flex-col gap-1">
          <span class="text-heading-3 text-n-slate-12">
            {{ t('REDE.PERSON.CALL.PROJECT') }}
          </span>
          <Select
            data-test="call-project"
            class="!w-full"
            :model-value="projectId"
            :options="projectOptions"
            :placeholder="t('REDE.PERSON.CALL.PROJECT_PLACEHOLDER')"
            :error="errors.project"
            @update:model-value="onProjectChange"
          />
          <p v-if="errors.project" class="mb-0 text-sm text-n-ruby-11">
            {{ errors.project }}
          </p>
        </div>
        <div v-if="fronts.length" class="flex flex-col gap-1">
          <span class="text-heading-3 text-n-slate-12">
            {{ t('REDE.PERSON.CALL.FRONT') }}
          </span>
          <Select
            v-model="frontId"
            data-test="call-front"
            class="!w-full"
            :options="frontOptions"
          />
        </div>
        <div class="flex flex-col gap-1">
          <span class="text-heading-3 text-n-slate-12">
            {{ t('REDE.PERSON.CALL.ANSWERED') }}
          </span>
          <Select
            v-model="answered"
            data-test="call-answered"
            class="!w-full"
            :options="answeredOptions"
            :placeholder="t('REDE.PERSON.CALL.ANSWERED_PLACEHOLDER')"
            :error="errors.answered"
          />
          <p v-if="errors.answered" class="mb-0 text-sm text-n-ruby-11">
            {{ errors.answered }}
          </p>
        </div>
        <div class="flex flex-col gap-1">
          <Input
            v-model="occurredAt"
            data-test="call-occurred-at"
            type="datetime-local"
            :label="t('REDE.PERSON.CALL.OCCURRED_AT')"
            :max="toDateTimeInput(new Date())"
          />
          <p v-if="errors.occurredAt" class="mb-0 text-sm text-n-ruby-11">
            {{ errors.occurredAt }}
          </p>
        </div>
      </div>

      <div class="flex flex-col gap-1" data-test="call-author">
        <span class="text-heading-3 text-n-slate-12">
          {{ t('REDE.PERSON.CALL.AUTHOR') }}
        </span>
        <span class="text-sm text-n-slate-11">{{ authorName }}</span>
      </div>

      <TextArea
        v-model="summary"
        data-test="call-summary"
        :label="t('REDE.PERSON.CALL.SUMMARY')"
        :max-length="2000"
      />

      <p v-if="errorMessage" class="mb-0 text-sm text-n-ruby-11" role="alert">
        {{ errorMessage }}
      </p>
    </div>
  </Dialog>
</template>
