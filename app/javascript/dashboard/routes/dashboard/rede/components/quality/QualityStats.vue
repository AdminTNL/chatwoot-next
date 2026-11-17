<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  counts: { type: Object, default: () => ({}) },
});

const { t } = useI18n();

const cards = computed(() => [
  {
    key: 'duplicates',
    label: t('REDE.QUALITY.STATS.DUPLICATES'),
    value: props.counts.duplicates ?? 0,
  },
  {
    key: 'incompletes',
    label: t('REDE.QUALITY.STATS.INCOMPLETES'),
    value: props.counts.incompletes ?? 0,
  },
  {
    key: 'resolved',
    label: t('REDE.QUALITY.STATS.RESOLVED_THIS_MONTH'),
    value: props.counts.resolvedThisMonth ?? 0,
  },
]);
</script>

<template>
  <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
    <div
      v-for="card in cards"
      :key="card.key"
      :data-test="`stat-${card.key}`"
      class="flex flex-col gap-1 p-4 border rounded-xl border-n-weak bg-n-solid-2"
    >
      <span class="text-heading-1 text-n-slate-12">{{ card.value }}</span>
      <span class="text-body-main text-n-slate-11">{{ card.label }}</span>
    </div>
  </div>
</template>
