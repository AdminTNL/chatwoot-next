<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { getTemperature } from '../../helpers/temperature';

// A cor nunca vem sozinha: a etiqueta sempre mostra o rótulo do nível.
const props = defineProps({
  level: { type: String, default: null },
});

const { t } = useI18n();
const temperature = computed(() => getTemperature(props.level));
</script>

<template>
  <span
    class="inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-md whitespace-nowrap"
    :class="temperature.badgeClass"
  >
    {{ t(temperature.labelKey) }}
  </span>
</template>
