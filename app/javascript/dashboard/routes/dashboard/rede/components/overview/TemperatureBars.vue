<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { TEMPERATURE_LEVELS, getTemperature } from '../../helpers/temperature';

const props = defineProps({
  counts: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['select']);

const { t } = useI18n();

const total = computed(() =>
  TEMPERATURE_LEVELS.reduce(
    (sum, level) => sum + (Number(props.counts?.[level]) || 0),
    0
  )
);

const rows = computed(() =>
  TEMPERATURE_LEVELS.map(level => {
    const count = Number(props.counts?.[level]) || 0;
    const temperature = getTemperature(level);
    return {
      level,
      count,
      label: t(temperature.labelKey),
      badgeClass: temperature.badgeClass,
      // Contagem pequena continua visível: mínimo de 2% quando count > 0.
      width:
        total.value > 0 && count > 0
          ? Math.max(2, Math.round((count / total.value) * 100))
          : 0,
    };
  })
);
</script>

<template>
  <ul class="flex flex-col gap-2 p-0 mb-0 list-none">
    <li v-for="row in rows" :key="row.level">
      <button
        type="button"
        :data-level="row.level"
        class="flex items-center w-full gap-3 px-2 py-1.5 text-start rounded-lg hover:bg-n-alpha-1 focus-visible:ring-2 focus-visible:ring-n-brand outline-none"
        @click="emit('select', row.level)"
      >
        <span
          class="w-32 px-2 py-0.5 text-center rounded-md shrink-0 text-label"
          :class="row.badgeClass"
        >
          {{ row.label }}
        </span>
        <span class="flex-1 h-2 overflow-hidden rounded-full bg-n-alpha-1">
          <span
            data-test="bar"
            class="block h-full rounded-full bg-current"
            :class="row.badgeClass"
            :style="{ width: `${row.width}%` }"
          />
        </span>
        <span class="w-10 text-end tabular-nums text-body-main text-n-slate-12">
          {{ row.count }}
        </span>
      </button>
    </li>
  </ul>
</template>
