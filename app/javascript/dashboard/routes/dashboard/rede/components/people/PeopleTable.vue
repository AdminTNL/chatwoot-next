<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import { getTemperature } from '../../helpers/temperature';
import TemperatureBadge from './TemperatureBadge.vue';
import ProjectBadge from './ProjectBadge.vue';
import LastContact from './LastContact.vue';

const props = defineProps({
  rows: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  // Valor de `sort` da API (ex.: `-name`); vazio é a ordem padrão da API.
  sort: { type: String, default: '' },
  // Projetos de GET people/filters, para saber se uma frente foi encerrada.
  projects: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:sort']);

const { t } = useI18n();

const SORTABLE = { 0: 'name', 4: 'temperature', 6: 'last_contact_at' };

const headers = computed(() => [
  t('REDE.PEOPLE.COLUMNS.PERSON'),
  t('REDE.PEOPLE.COLUMNS.PROJECT'),
  t('REDE.PEOPLE.COLUMNS.FRONT'),
  t('REDE.PEOPLE.COLUMNS.ROLE'),
  t('REDE.PEOPLE.COLUMNS.TEMPERATURE'),
  t('REDE.PEOPLE.COLUMNS.RESPONSIBLE'),
  t('REDE.PEOPLE.COLUMNS.LAST_CONTACT'),
  t('REDE.PEOPLE.COLUMNS.NEXT_STEP'),
]);

const closedFrontIds = computed(
  () =>
    new Set(
      props.projects.flatMap(project =>
        (project.fronts || [])
          .filter(front => front.status === 'closed')
          .map(front => front.id)
      )
    )
);

const rowClass = row => getTemperature(row.temperature).rowClass;
const title = row =>
  row.contact?.name || row.contact?.phoneNumber || t('REDE.PEOPLE.UNNAMED');
const showPhone = row => row.contact?.name && row.contact?.phoneNumber;
const isFrontClosed = row =>
  row.front?.status === 'closed' || closedFrontIds.value.has(row.front?.id);

// Ciclo do cabeçalho: ordem padrão, crescente, decrescente, ordem padrão.
const sortState = field => {
  if (props.sort === field) return 'ascending';
  if (props.sort === `-${field}`) return 'descending';
  return 'none';
};
const toggleSort = field => {
  const state = sortState(field);
  if (state === 'none') emit('update:sort', field);
  else if (state === 'ascending') emit('update:sort', `-${field}`);
  else emit('update:sort', '');
};
const sortIcon = field => {
  const state = sortState(field);
  if (state === 'ascending') return 'i-lucide-arrow-up';
  if (state === 'descending') return 'i-lucide-arrow-down';
  return 'i-lucide-arrow-up-down';
};
</script>

<template>
  <div class="w-full overflow-x-auto">
    <BaseTable :headers="headers" :items="rows" :loading="loading">
      <template
        v-for="(field, index) in SORTABLE"
        :key="field"
        #[`header-${index}`]="{ header }"
      >
        <button
          type="button"
          class="inline-flex items-center gap-1 capitalize text-heading-3 text-n-slate-12"
          :data-test="`sort-${field}`"
          :aria-sort="sortState(field)"
          @click="toggleSort(field)"
        >
          {{ header }}
          <span class="size-3.5" :class="sortIcon(field)" />
        </button>
      </template>

      <template #row="{ items }">
        <BaseTableRow
          v-for="row in items"
          :key="row.rowKey"
          :item="row"
          data-test="people-row"
          :class="rowClass(row)"
        >
          <BaseTableCell class="pl-3">
            <router-link
              :to="{
                name: 'rede_person',
                params: { contactId: row.contact.id },
              }"
              class="block font-medium text-n-slate-12 hover:underline"
            >
              {{ title(row) }}
            </router-link>
            <span v-if="showPhone(row)" class="block text-sm text-n-slate-11">
              {{ row.contact.phoneNumber }}
            </span>
          </BaseTableCell>
          <BaseTableCell>
            <ProjectBadge :project="row.project" />
          </BaseTableCell>
          <BaseTableCell data-test="cell-front">
            <span
              v-if="row.frontPending"
              class="inline-flex px-2 py-0.5 text-xs font-medium rounded-md bg-n-amber-3 text-n-amber-11 whitespace-nowrap"
            >
              {{ t('REDE.PEOPLE.FRONT_PENDING') }}
            </span>
            <template v-else-if="row.front">
              {{ row.front.name }}
              <span v-if="isFrontClosed(row)" class="text-n-slate-10">
                {{ t('REDE.PEOPLE.FRONT_CLOSED') }}
              </span>
            </template>
            <template v-else>{{ t('REDE.PEOPLE.NO_VALUE') }}</template>
          </BaseTableCell>
          <BaseTableCell>
            {{ row.role?.name || t('REDE.PEOPLE.NO_VALUE') }}
          </BaseTableCell>
          <BaseTableCell>
            <TemperatureBadge :level="row.temperature" />
          </BaseTableCell>
          <BaseTableCell>
            {{ row.responsible?.name || t('REDE.PEOPLE.NO_VALUE') }}
          </BaseTableCell>
          <BaseTableCell>
            <LastContact :value="row.lastContactAt" />
          </BaseTableCell>
          <BaseTableCell class="max-w-64">
            <span
              v-if="row.nextStep"
              class="block truncate"
              :title="row.nextStep"
            >
              {{ row.nextStep }}
            </span>
            <template v-else>{{ t('REDE.PEOPLE.NO_VALUE') }}</template>
          </BaseTableCell>
        </BaseTableRow>
      </template>
    </BaseTable>
  </div>
</template>
