<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import { TEMPERATURE_LEVELS, TEMPERATURES } from '../../helpers/temperature';

const props = defineProps({
  // Parâmetros da API (os mesmos de peopleQuery), já lidos da URL.
  modelValue: { type: Object, default: () => ({}) },
  // Resposta de GET people/filters: { projects: [{ fronts }], responsibles }.
  options: {
    type: Object,
    default: () => ({ projects: [], responsibles: [] }),
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const FILTER_KEYS = [
  'project_ids',
  'front_ids',
  'temperatures',
  'responsible_ids',
  'city',
  'no_contact_days',
  'q',
  'include_closed',
];
const PRESET_DAYS = [7, 15, 30];
const NONE = 'none';
const SEARCH_DEBOUNCE_MS = 300;

const isEmpty = value =>
  value === undefined ||
  value === null ||
  value === '' ||
  value === false ||
  (Array.isArray(value) && value.length === 0);

// Troca de filtro sempre volta para a página 1: a página sai dos parâmetros.
const emitChange = patch => {
  const next = { ...props.modelValue, ...patch };
  delete next.page;
  Object.keys(next).forEach(key => {
    if (isEmpty(next[key])) delete next[key];
  });
  emit('update:modelValue', next);
};

const clear = () => {
  const next = { ...props.modelValue };
  delete next.page;
  FILTER_KEYS.forEach(key => delete next[key]);
  emit('update:modelValue', next);
};

const hasFilters = computed(() =>
  FILTER_KEYS.some(key => !isEmpty(props.modelValue[key]))
);

const includeClosed = computed(() => props.modelValue.include_closed === true);
const selectedProjectIds = computed(() => props.modelValue.project_ids || []);

const projectOptions = computed(() =>
  (props.options.projects || [])
    .filter(
      project =>
        project.status !== 'closed' ||
        includeClosed.value ||
        selectedProjectIds.value.includes(project.id)
    )
    .map(project => ({ value: project.id, label: project.name }))
);

// Frentes agrupadas por projeto (o rótulo leva o nome do projeto) e
// restritas aos projetos escolhidos, quando houver.
const frontOptions = computed(() => {
  const chosen = selectedProjectIds.value;
  const fronts = (props.options.projects || [])
    .filter(project => !chosen.length || chosen.includes(project.id))
    .flatMap(project =>
      (project.fronts || []).map(front => ({
        value: front.id,
        label: `${project.name} · ${front.name}${
          front.status === 'closed' ? ` ${t('REDE.PEOPLE.FRONT_CLOSED')}` : ''
        }`,
      }))
    );
  return [...fronts, { value: NONE, label: t('REDE.PEOPLE.FILTERS.NO_FRONT') }];
});

const temperatureOptions = computed(() =>
  TEMPERATURE_LEVELS.map(level => ({
    value: level,
    label: t(TEMPERATURES[level].labelKey),
  }))
);

const responsibleOptions = computed(() => [
  ...(props.options.responsibles || []).map(user => ({
    value: user.id,
    label: user.name,
  })),
  { value: NONE, label: t('REDE.PEOPLE.FILTERS.NO_RESPONSIBLE') },
]);

const noContactOptions = computed(() => [
  { value: '', label: t('REDE.PEOPLE.FILTERS.NO_CONTACT_ANY') },
  ...PRESET_DAYS.map(n => ({
    value: n,
    label: t('REDE.PEOPLE.FILTERS.NO_CONTACT_DAYS', { n }),
  })),
  { value: 'custom', label: t('REDE.PEOPLE.FILTERS.NO_CONTACT_CUSTOM') },
]);

// O ComboBox muta o array que recebe, então cada um ganha uma cópia.
const copy = key => [...(props.modelValue[key] || [])];

// Busca e cidade esperam 300 ms sem digitar antes de ir para a URL.
const search = ref(props.modelValue.q || '');
const city = ref(props.modelValue.city || '');
watch(
  () => props.modelValue.q,
  value => {
    search.value = value || '';
  }
);
watch(
  () => props.modelValue.city,
  value => {
    city.value = value || '';
  }
);
const emitSearch = useDebounceFn(
  value => emitChange({ q: String(value).trim() }),
  SEARCH_DEBOUNCE_MS
);
const emitCity = useDebounceFn(
  value => emitChange({ city: String(value).trim() }),
  SEARCH_DEBOUNCE_MS
);
const onSearch = value => {
  search.value = value;
  emitSearch(value);
};
const onCity = value => {
  city.value = value;
  emitCity(value);
};

// "Personalizado" mostra um campo de dias; os 3 prazos fixos vão direto.
const customDays = ref(false);
watch(
  () => props.modelValue.no_contact_days,
  days => {
    if (days && !PRESET_DAYS.includes(days)) customDays.value = true;
  },
  { immediate: true }
);
const noContactValue = computed(() => {
  const days = props.modelValue.no_contact_days;
  if (customDays.value) return 'custom';
  return days || '';
});
const onNoContact = value => {
  customDays.value = value === 'custom';
  if (value === 'custom') return;
  emitChange({ no_contact_days: value === '' ? undefined : Number(value) });
};
const onCustomDays = value => {
  const days = Number(value);
  emitChange({ no_contact_days: days > 0 ? days : undefined });
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
      <div class="flex flex-col gap-1">
        <span class="text-heading-3 text-n-slate-12">
          {{ t('REDE.PEOPLE.FILTERS.PROJECT') }}
        </span>
        <TagMultiSelectComboBox
          data-test="filter-projects"
          :options="projectOptions"
          :model-value="copy('project_ids')"
          @update:model-value="emitChange({ project_ids: [...$event] })"
        />
        <label class="flex items-center gap-2 mb-0 text-sm text-n-slate-11">
          <input
            type="checkbox"
            data-test="filter-include-closed"
            class="mb-0"
            :checked="includeClosed"
            @change="emitChange({ include_closed: $event.target.checked })"
          />
          {{ t('REDE.PEOPLE.FILTERS.INCLUDE_CLOSED') }}
        </label>
      </div>
      <div class="flex flex-col gap-1">
        <span class="text-heading-3 text-n-slate-12">
          {{ t('REDE.PEOPLE.FILTERS.FRONT') }}
        </span>
        <TagMultiSelectComboBox
          data-test="filter-fronts"
          :options="frontOptions"
          :model-value="copy('front_ids')"
          @update:model-value="emitChange({ front_ids: [...$event] })"
        />
      </div>
      <div class="flex flex-col gap-1">
        <span class="text-heading-3 text-n-slate-12">
          {{ t('REDE.PEOPLE.FILTERS.TEMPERATURE') }}
        </span>
        <TagMultiSelectComboBox
          data-test="filter-temperatures"
          :options="temperatureOptions"
          :model-value="copy('temperatures')"
          @update:model-value="emitChange({ temperatures: [...$event] })"
        />
      </div>
      <div class="flex flex-col gap-1">
        <span class="text-heading-3 text-n-slate-12">
          {{ t('REDE.PEOPLE.FILTERS.RESPONSIBLE') }}
        </span>
        <TagMultiSelectComboBox
          data-test="filter-responsibles"
          :options="responsibleOptions"
          :model-value="copy('responsible_ids')"
          @update:model-value="emitChange({ responsible_ids: [...$event] })"
        />
      </div>
    </div>

    <div class="flex flex-wrap items-end gap-3">
      <div class="w-48">
        <Input
          data-test="filter-city"
          :label="t('REDE.PEOPLE.FILTERS.CITY')"
          :model-value="city"
          @update:model-value="onCity"
        />
      </div>
      <div class="flex flex-col gap-1">
        <span class="text-heading-3 text-n-slate-12">
          {{ t('REDE.PEOPLE.FILTERS.NO_CONTACT') }}
        </span>
        <div class="flex items-center gap-2">
          <Select
            data-test="filter-no-contact"
            :model-value="noContactValue"
            :options="noContactOptions"
            @update:model-value="onNoContact"
          />
          <div v-if="customDays" class="w-24">
            <Input
              data-test="filter-custom-days"
              type="number"
              min="1"
              :placeholder="t('REDE.PEOPLE.FILTERS.CUSTOM_DAYS')"
              :model-value="modelValue.no_contact_days || ''"
              @update:model-value="onCustomDays"
            />
          </div>
        </div>
      </div>
      <div class="flex-1 min-w-48">
        <Input
          data-test="filter-search"
          :label="t('REDE.PEOPLE.FILTERS.SEARCH')"
          :model-value="search"
          @update:model-value="onSearch"
        />
      </div>
      <Button
        v-if="hasFilters"
        data-test="filter-clear"
        variant="faded"
        color="slate"
        size="md"
        type="button"
        icon="i-lucide-filter-x"
        :label="t('REDE.PEOPLE.FILTERS.CLEAR')"
        @click="clear"
      />
    </div>
  </div>
</template>
