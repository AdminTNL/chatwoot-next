<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

// Adicionar nota: projeto, frente opcional e texto. Emite `submit`.
const props = defineProps({
  projects: { type: Array, default: () => [] },
  frontsByProject: { type: Object, default: () => ({}) },
  isLoading: { type: Boolean, default: false },
  errorMessage: { type: String, default: '' },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const dialogRef = ref(null);
const projectId = ref('');
const frontId = ref('');
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

const open = () => {
  projectId.value = props.projects.length === 1 ? props.projects[0].id : '';
  frontId.value = '';
  summary.value = '';
  errors.value = {};
  dialogRef.value?.open();
};
const close = () => dialogRef.value?.close();

const onProjectChange = value => {
  projectId.value = value;
  frontId.value = '';
};

const submit = () => {
  const found = {};
  if (!projectId.value) {
    found.project = t('REDE.PERSON.CALL.ERRORS.PROJECT_REQUIRED');
  }
  if (!summary.value.trim()) {
    found.summary = t('REDE.PERSON.NOTE.ERRORS.SUMMARY_REQUIRED');
  }
  errors.value = found;
  if (Object.keys(found).length) return;
  const payload = {
    projectId: Number(projectId.value),
    summary: summary.value.trim(),
  };
  if (frontId.value) payload.frontId = Number(frontId.value);
  emit('submit', payload);
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    overflow-y-auto
    :title="t('REDE.PERSON.NOTE.TITLE')"
    :confirm-button-label="t('REDE.PERSON.NOTE.CONFIRM')"
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
            data-test="note-project"
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
            data-test="note-front"
            class="!w-full"
            :options="frontOptions"
          />
        </div>
      </div>

      <div class="flex flex-col gap-1">
        <TextArea
          v-model="summary"
          data-test="note-summary"
          :label="t('REDE.PERSON.NOTE.SUMMARY')"
          :max-length="2000"
        />
        <p v-if="errors.summary" class="mb-0 text-sm text-n-ruby-11">
          {{ errors.summary }}
        </p>
      </div>

      <p v-if="errorMessage" class="mb-0 text-sm text-n-ruby-11" role="alert">
        {{ errorMessage }}
      </p>
    </div>
  </Dialog>
</template>
