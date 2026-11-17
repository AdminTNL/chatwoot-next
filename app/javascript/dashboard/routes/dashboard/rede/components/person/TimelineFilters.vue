<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import {
  PERIOD_SHORTCUTS,
  TIMELINE_TYPES,
  periodShortcut,
} from './timelineFilters';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  projects: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const invalidRange = ref(false);

const projectOptions = computed(() => [
  { value: '', label: t('REDE.PERSON.FILTERS.ALL_PROJECTS') },
  ...props.projects.map(project => ({
    value: project.id,
    label: project.name,
  })),
]);

const selectedTypes = computed(() => props.modelValue.types || []);

const update = patch =>
  emit('update:modelValue', { ...props.modelValue, ...patch });

// Período invertido não é enviado: a API responderia 422.
const updateDate = (key, value) => {
  const next = { ...props.modelValue, [key]: value };
  if (next.from && next.to && next.from > next.to) {
    invalidRange.value = true;
    return;
  }
  invalidRange.value = false;
  emit('update:modelValue', next);
};

const toggleType = type => {
  const types = selectedTypes.value.includes(type)
    ? selectedTypes.value.filter(item => item !== type)
    : [...selectedTypes.value, type];
  update({ types });
};

const applyShortcut = days => {
  invalidRange.value = false;
  update(periodShortcut(days));
};

const clear = () => {
  invalidRange.value = false;
  emit('update:modelValue', {});
};

const hasFilters = computed(() =>
  Boolean(
    props.modelValue.projectId ||
      props.modelValue.from ||
      props.modelValue.to ||
      selectedTypes.value.length
  )
);
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex flex-wrap items-end gap-3">
      <div class="flex flex-col gap-1">
        <span class="text-heading-3 text-n-slate-12">
          {{ t('REDE.PERSON.FILTERS.PROJECT') }}
        </span>
        <Select
          data-test="filter-project"
          :model-value="modelValue.projectId || ''"
          :options="projectOptions"
          @update:model-value="
            value => update({ projectId: value ? Number(value) : undefined })
          "
        />
      </div>
      <Input
        data-test="filter-from"
        type="date"
        :label="t('REDE.PERSON.FILTERS.FROM')"
        :model-value="modelValue.from || ''"
        @update:model-value="value => updateDate('from', value)"
      />
      <Input
        data-test="filter-to"
        type="date"
        :label="t('REDE.PERSON.FILTERS.TO')"
        :model-value="modelValue.to || ''"
        @update:model-value="value => updateDate('to', value)"
      />
      <div class="flex gap-1">
        <button
          v-for="days in PERIOD_SHORTCUTS"
          :key="days"
          type="button"
          class="px-2.5 py-1.5 text-sm rounded-lg bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12"
          :data-test="`period-${days}`"
          @click="applyShortcut(days)"
        >
          {{ t('REDE.PERSON.FILTERS.LAST_DAYS', { days }) }}
        </button>
      </div>
    </div>
    <p v-if="invalidRange" class="mb-0 text-sm text-n-ruby-11" role="alert">
      {{ t('REDE.PERSON.FILTERS.INVALID_RANGE') }}
    </p>
    <div class="flex flex-wrap items-center gap-2">
      <button
        v-for="type in TIMELINE_TYPES"
        :key="type"
        type="button"
        class="px-2.5 py-1 text-sm font-medium rounded-lg"
        :class="
          selectedTypes.includes(type)
            ? 'bg-n-brand/10 text-n-brand'
            : 'bg-n-alpha-2 text-n-slate-11'
        "
        :aria-pressed="selectedTypes.includes(type)"
        :data-test="`type-${type.replace('_change', '')}`"
        @click="toggleType(type)"
      >
        {{ t(`REDE.PERSON.TYPES.${type.toUpperCase()}`) }}
      </button>
      <button
        v-if="hasFilters"
        type="button"
        class="px-2.5 py-1 text-sm text-n-slate-11 hover:text-n-slate-12"
        data-test="filters-clear"
        @click="clear"
      >
        {{ t('REDE.PERSON.FILTERS.CLEAR') }}
      </button>
    </div>
  </div>
</template>
