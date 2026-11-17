<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import { TEMPERATURE_LEVELS, getTemperature } from '../../helpers/temperature';

// Seletor dos 4 níveis mais "Sem temperatura" (level null), com nota opcional.
// Reaproveitado na 018. Quem usa decide se mostra (só frente com has_temperature).
const props = defineProps({
  modelValue: { type: String, default: null },
  disabled: { type: Boolean, default: false },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['save']);

const { t } = useI18n();

const current = computed(() => props.modelValue || 'none');
const level = ref(current.value);
const note = ref('');

watch(current, value => {
  level.value = value;
  note.value = '';
});

const options = computed(() =>
  TEMPERATURE_LEVELS.map(item => ({
    value: item,
    label: t(getTemperature(item).labelKey),
  }))
);

// Registrar o mesmo nível sem nota só criaria uma linha repetida no histórico.
const canSave = computed(
  () =>
    !props.disabled &&
    (level.value !== current.value || note.value.trim().length > 0)
);

const save = () => {
  if (!canSave.value) return;
  emit('save', {
    level: level.value === 'none' ? null : level.value,
    note: note.value.trim() || null,
  });
};
</script>

<template>
  <div class="flex flex-wrap items-end gap-2">
    <Select
      v-model="level"
      data-test="temperature-select"
      :options="options"
      :disabled="disabled"
      :aria-label="t('REDE.PERSON.TEMPERATURE.LABEL')"
    />
    <Input
      v-model="note"
      data-test="temperature-note"
      class="min-w-40 grow"
      size="sm"
      :disabled="disabled"
      :placeholder="t('REDE.PERSON.TEMPERATURE.NOTE_PLACEHOLDER')"
    />
    <Button
      data-test="temperature-save"
      type="button"
      size="sm"
      variant="faded"
      color="slate"
      :label="t('REDE.PERSON.TEMPERATURE.SAVE')"
      :is-loading="isLoading"
      :disabled="!canSave"
      @click="save"
    />
  </div>
</template>
