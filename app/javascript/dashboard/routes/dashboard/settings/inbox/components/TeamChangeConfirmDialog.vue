<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  teamName: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['confirm', 'cancel']);

const { t } = useI18n();

const dialogRef = ref(null);
const isConfirmed = ref(false);

const i18nKey = 'INBOX_MGMT.SETTINGS_POPUP.RESPONSIBLE_TEAM.CHANGE_CONFIRM';

const title = computed(() =>
  props.teamName
    ? t(`${i18nKey}.TITLE`, { teamName: props.teamName })
    : t(`${i18nKey}.TITLE_NO_TEAM`)
);

const description = computed(() =>
  props.teamName ? t(`${i18nKey}.MIGRATION`) : t(`${i18nKey}.MIGRATION_NO_TEAM`)
);

const open = () => {
  isConfirmed.value = false;
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const onConfirm = () => {
  isConfirmed.value = true;
  emit('confirm');
  close();
};

// Dialog emits `close` for any closing path (cancel, click outside, ESC).
const onClose = () => {
  if (!isConfirmed.value) emit('cancel');
  isConfirmed.value = false;
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="alert"
    :title="title"
    :confirm-button-label="t(`${i18nKey}.CONFIRM`)"
    @confirm="onConfirm"
    @close="onClose"
  >
    <template #description>
      <div class="flex flex-col gap-2 text-sm text-n-slate-11">
        <p class="mb-0">{{ description }}</p>
        <ul class="mb-0 ms-4 list-disc">
          <li>{{ t(`${i18nKey}.LABELS`) }}</li>
          <li>{{ t(`${i18nKey}.ACCESS`) }}</li>
        </ul>
      </div>
    </template>
  </Dialog>
</template>
