<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

// Último contato em data relativa. Vermelho quando passa de 7 dias ou é nulo.
const props = defineProps({
  value: { type: String, default: null },
});

const STALE_AFTER_MS = 7 * 24 * 60 * 60 * 1000;
const UNITS = [
  ['year', 365 * 24 * 60 * 60 * 1000],
  ['month', 30 * 24 * 60 * 60 * 1000],
  ['day', 24 * 60 * 60 * 1000],
  ['hour', 60 * 60 * 1000],
  ['minute', 60 * 1000],
];

const { t, locale } = useI18n();

const date = computed(() => (props.value ? new Date(props.value) : null));
const age = computed(() =>
  date.value ? Date.now() - date.value.getTime() : 0
);
const isStale = computed(() => !date.value || age.value > STALE_AFTER_MS);

const label = computed(() => {
  if (!date.value) return t('REDE.PEOPLE.NEVER');
  const formatter = new Intl.RelativeTimeFormat(
    locale.value.replace('_', '-'),
    {
      numeric: 'auto',
    }
  );
  const [unit, size] = UNITS.find(([, ms]) => age.value >= ms) || UNITS[4];
  return formatter.format(-Math.floor(age.value / size), unit);
});

const fullDate = computed(() =>
  date.value
    ? date.value.toLocaleString(locale.value.replace('_', '-'))
    : t('REDE.PEOPLE.NEVER')
);
</script>

<template>
  <span
    class="text-sm whitespace-nowrap"
    :class="isStale ? 'text-n-ruby-11' : 'text-n-slate-11'"
    :title="fullDate"
  >
    {{ label }}
  </span>
</template>
