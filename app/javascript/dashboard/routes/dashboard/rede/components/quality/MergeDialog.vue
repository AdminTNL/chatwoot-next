<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

defineProps({
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['confirm']);

const { t } = useI18n();

const dialogRef = ref(null);
const pair = ref(null);
const baseId = ref(null);

const people = computed(() =>
  pair.value ? [pair.value.contactA, pair.value.contactB] : []
);

// Chamado pelo pai com o par escolhido. Sempre abre sem base marcado.
const open = selectedPair => {
  pair.value = selectedPair;
  baseId.value = null;
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const submit = () => {
  if (!pair.value || baseId.value === null) return;
  const mergee = people.value.find(person => person.id !== baseId.value);
  emit('confirm', {
    projectId: pair.value.projectId,
    baseContactId: baseId.value,
    mergeeContactId: mergee.id,
  });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('REDE.QUALITY.MERGE.TITLE')"
    :confirm-button-label="t('REDE.QUALITY.MERGE.CONFIRM')"
    :disable-confirm-button="baseId === null"
    :is-loading="isLoading"
    @confirm="submit"
  >
    <div class="flex flex-col gap-4">
      <p class="mb-0 text-body-main text-n-slate-11">
        {{ t('REDE.QUALITY.MERGE.CHOOSE') }}
      </p>
      <label
        v-for="person in people"
        :key="person.id"
        class="flex items-start gap-3 p-3 border rounded-lg cursor-pointer border-n-weak"
        :class="{ 'border-n-brand': baseId === person.id }"
      >
        <input
          v-model="baseId"
          type="radio"
          name="merge-base"
          :value="person.id"
          :data-test="`base-${person.id}`"
          class="mt-1"
        />
        <span class="flex flex-col min-w-0">
          <span class="text-heading-3 text-n-slate-12 truncate">
            {{ person.name || t('REDE.QUALITY.PAIR.NO_NAME') }}
          </span>
          <span class="text-body-main text-n-slate-11">
            {{ person.phoneNumber || t('REDE.QUALITY.PAIR.EMPTY') }}
          </span>
        </span>
      </label>
      <p
        data-test="irreversible-warning"
        class="mb-0 text-body-main text-n-ruby-11"
      >
        {{ t('REDE.QUALITY.MERGE.WARNING') }}
      </p>
    </div>
  </Dialog>
</template>
