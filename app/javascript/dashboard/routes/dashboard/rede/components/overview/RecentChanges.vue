<script setup>
import { useI18n } from 'vue-i18n';
import { getTemperature } from '../../helpers/temperature';

defineProps({
  changes: { type: Array, default: () => [] },
});

const { t, locale } = useI18n();

const UNITS = [
  ['day', 86400],
  ['hour', 3600],
  ['minute', 60],
];

const relativeTime = value => {
  const time = new Date(value).getTime();
  if (Number.isNaN(time)) return '';
  const seconds = Math.round((time - Date.now()) / 1000);
  const formatter = new Intl.RelativeTimeFormat(
    String(locale.value).replace('_', '-'),
    { numeric: 'auto' }
  );
  const [unit, size] =
    UNITS.find(([, s]) => Math.abs(seconds) >= s) || UNITS[UNITS.length - 1];
  return formatter.format(Math.round(seconds / size), unit);
};

const levelLabel = level => t(getTemperature(level || 'none').labelKey);

// Tipo desconhecido cai numa frase genérica: a visão geral nunca quebra por um evento novo.
const describe = change => {
  switch (change.type) {
    case 'temperature_change':
      return t('REDE.OVERVIEW.CHANGE.TEMPERATURE', {
        from: levelLabel(change.data?.from),
        to: levelLabel(change.data?.to),
      });
    case 'participation_joined':
      return t('REDE.OVERVIEW.CHANGE.JOINED');
    case 'assignment_change':
      return t('REDE.OVERVIEW.CHANGE.ASSIGNMENT');
    default:
      return t('REDE.OVERVIEW.CHANGE.UNKNOWN');
  }
};

const keyOf = (change, index) =>
  `${change.type}-${change.contact?.id}-${change.occurredAt}-${index}`;
</script>

<template>
  <p
    v-if="!changes.length"
    class="mb-0 text-body-main text-n-slate-11"
    data-test="empty"
  >
    {{ t('REDE.OVERVIEW.RECENT.EMPTY') }}
  </p>
  <ul v-else class="flex flex-col p-0 mb-0 list-none divide-y divide-n-weak">
    <li
      v-for="(change, index) in changes"
      :key="keyOf(change, index)"
      data-test="change"
      class="flex flex-wrap items-center justify-between gap-x-4 gap-y-1 py-2.5"
    >
      <div class="flex flex-col min-w-0 gap-0.5">
        <p class="mb-0 text-body-main text-n-slate-12">
          <RouterLink
            v-if="change.contact"
            :to="{
              name: 'rede_person',
              params: { contactId: change.contact.id },
            }"
            class="font-medium hover:underline"
          >
            {{ change.contact.name }}
          </RouterLink>
          <span class="text-n-slate-11"> {{ describe(change) }}</span>
        </p>
        <p
          class="flex flex-wrap items-center gap-2 mb-0 text-label text-n-slate-11"
        >
          <span v-if="change.project" class="inline-flex items-center gap-1.5">
            <span
              class="inline-block rounded-full size-2"
              :style="{ backgroundColor: change.project.color }"
            />
            {{ change.project.name }}
          </span>
          <span v-if="change.front" class="inline-flex items-center gap-1.5">
            <span class="text-n-slate-10">/</span>
            {{ change.front.name }}
          </span>
        </p>
      </div>
      <span class="text-label text-n-slate-11 shrink-0">
        {{ relativeTime(change.occurredAt) }}
      </span>
    </li>
  </ul>
</template>
