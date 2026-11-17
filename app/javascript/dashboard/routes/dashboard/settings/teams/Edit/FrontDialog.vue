<script setup>
import { ref, reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useRedeProjectsStore } from 'dashboard/stores/rede/projects';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  projectId: { type: Number, required: true },
});

const { t } = useI18n();
const projectsStore = useRedeProjectsStore();

const dialogRef = ref(null);
const editingFront = ref(null);
const submitted = ref(false);
const state = reactive({ name: '', hasTemperature: false });

const isEditing = computed(() => !!editingFront.value);
const nameError = computed(() =>
  submitted.value && !state.name.trim() ? t('REDE.FRONTS.NAME_REQUIRED') : ''
);

// Chamado pelo pai: sem frente abre em branco, com frente abre para edição.
const open = front => {
  editingFront.value = front || null;
  state.name = front?.name || '';
  state.hasTemperature = front?.hasTemperature || false;
  submitted.value = false;
  dialogRef.value?.open();
};

const submit = async () => {
  submitted.value = true;
  if (!state.name.trim()) return;
  const attrs = {
    name: state.name.trim(),
    has_temperature: state.hasTemperature,
  };
  try {
    if (isEditing.value) {
      await projectsStore.updateFront(
        props.projectId,
        editingFront.value.id,
        attrs
      );
    } else {
      await projectsStore.createFront(props.projectId, attrs);
    }
    useAlert(t('REDE.FRONTS.SAVE_SUCCESS'));
    dialogRef.value?.close();
  } catch (error) {
    useAlert(error?.message || t('REDE.FRONTS.SAVE_ERROR'));
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="
      isEditing
        ? t('REDE.FRONTS.DIALOG.EDIT_TITLE')
        : t('REDE.FRONTS.DIALOG.NEW_TITLE')
    "
    :confirm-button-label="t('REDE.FRONTS.DIALOG.SAVE')"
    :is-loading="projectsStore.uiFlags.updatingItem"
    @confirm="submit"
  >
    <div class="flex flex-col gap-4">
      <Input
        v-model="state.name"
        :label="t('REDE.FRONTS.DIALOG.NAME_LABEL')"
        :placeholder="t('REDE.FRONTS.DIALOG.NAME_PLACEHOLDER')"
        :message="nameError"
        :message-type="nameError ? 'error' : 'info'"
      />
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <Checkbox v-model="state.hasTemperature" />
        {{ t('REDE.FRONTS.HAS_TEMPERATURE') }}
      </label>
    </div>
  </Dialog>
</template>
