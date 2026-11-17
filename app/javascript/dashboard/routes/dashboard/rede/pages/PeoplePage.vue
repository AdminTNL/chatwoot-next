<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useRedePeopleStore } from 'dashboard/stores/rede/people';
import RolesAPI from 'dashboard/api/rede/roles';
import Button from 'dashboard/components-next/button/Button.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import CrmPageShell from '../components/CrmPageShell.vue';
import PeopleFilters from '../components/people/PeopleFilters.vue';
import PeopleTable from '../components/people/PeopleTable.vue';
import AddPersonDialog from '../components/people/AddPersonDialog.vue';
import { paramsToQuery, queryToParams } from '../helpers/peopleQuery';

const PER_PAGE = 25;

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useRedePeopleStore();

const addDialogRef = ref(null);
const roles = ref([]);

// A URL é a fonte dos filtros: recarregar a página mantém a lista.
const params = computed(() => queryToParams(route.query));
const filterParams = computed(() => {
  const rest = { ...params.value };
  delete rest.page;
  return rest;
});
const hasFilters = computed(
  () =>
    Object.keys(filterParams.value).filter(
      key => key !== 'sort' && key !== 'per_page'
    ).length > 0
);

const rows = computed(() => store.records);
const isLoading = computed(() => store.uiFlags.fetchingList);
const totalCount = computed(() => store.meta.totalCount || 0);
const currentPage = computed(() => params.value.page || 1);
const hasLoaded = ref(false);

const navigate = query => router.push({ query: paramsToQuery(query) });

const load = async () => {
  try {
    await store.get({ ...params.value, per_page: PER_PAGE });
  } catch {
    useAlert(t('REDE.PEOPLE.LOAD_ERROR'));
  } finally {
    hasLoaded.value = true;
  }
};

watch(() => route.query, load);

const onFiltersChange = next => navigate(next);
const onSort = sort => {
  // Trocar a ordem também volta para a página 1.
  const rest = { ...params.value };
  delete rest.page;
  delete rest.sort;
  navigate(sort ? { ...rest, sort } : rest);
};
const onPageChange = page => navigate({ ...params.value, page });
const clearFilters = () => {
  const { sort } = params.value;
  navigate(sort ? { sort } : {});
};

const openAddDialog = () => addDialogRef.value?.open();

const onSaved = ({ matchedContact, extrasSaved }) => {
  if (matchedContact) {
    useAlert(
      t('REDE.PEOPLE.ADD.FOUND_EXISTING', { name: matchedContact.name })
    );
  } else {
    useAlert(t('REDE.PEOPLE.ADD.SUCCESS'));
  }
  if (!extrasSaved) useAlert(t('REDE.PEOPLE.ADD.UPDATE_ERROR'));
  store.getFilterOptions().catch(() => {});
  load();
};

onMounted(() => {
  store.getFilterOptions().catch(() => {});
  RolesAPI.get()
    .then(({ data }) => {
      roles.value = data || [];
    })
    .catch(() => {});
  load();
});
</script>

<template>
  <CrmPageShell
    :title="t('REDE.CRM.PEOPLE.TITLE')"
    :description="t('REDE.CRM.PEOPLE.DESCRIPTION')"
  >
    <div class="flex flex-col gap-4">
      <div class="flex items-start justify-between gap-3">
        <p class="mb-0 text-body-main text-n-slate-11">
          {{ t('REDE.PEOPLE.HELP') }}
        </p>
        <Button
          data-test="add-person"
          icon="i-lucide-user-plus"
          :label="t('REDE.PEOPLE.ADD.BUTTON')"
          @click="openAddDialog"
        />
      </div>

      <PeopleFilters
        :model-value="filterParams"
        :options="store.filterOptions"
        @update:model-value="onFiltersChange"
      />

      <p
        v-if="hasLoaded"
        class="mb-0 text-sm text-n-slate-11"
        data-test="rows-count"
      >
        {{ t('REDE.PEOPLE.ROWS_COUNT', { count: totalCount }, totalCount) }}
      </p>

      <div
        v-if="hasLoaded && !isLoading && !rows.length"
        class="flex flex-col items-center gap-3 px-6 py-16 text-center border border-dashed rounded-xl border-n-weak"
        data-test="people-empty"
      >
        <span class="i-lucide-users size-8 text-n-slate-10" />
        <template v-if="hasFilters">
          <h2 class="mb-0 text-heading-2 text-n-slate-12">
            {{ t('REDE.PEOPLE.EMPTY.FILTERED_TITLE') }}
          </h2>
          <Button
            variant="faded"
            color="slate"
            :label="t('REDE.PEOPLE.FILTERS.CLEAR')"
            @click="clearFilters"
          />
        </template>
        <template v-else>
          <h2 class="mb-0 text-heading-2 text-n-slate-12">
            {{ t('REDE.PEOPLE.EMPTY.NO_FILTERS_TITLE') }}
          </h2>
          <p class="mb-0 text-body-main text-n-slate-11">
            {{ t('REDE.PEOPLE.EMPTY.NO_FILTERS_DESCRIPTION') }}
          </p>
          <Button :label="t('REDE.PEOPLE.ADD.BUTTON')" @click="openAddDialog" />
        </template>
      </div>

      <template v-else>
        <PeopleTable
          :rows="rows"
          :loading="isLoading"
          :sort="params.sort || ''"
          :projects="store.filterOptions.projects"
          @update:sort="onSort"
        />
        <div v-if="totalCount > PER_PAGE" class="relative">
          <PaginationFooter
            :current-page="currentPage"
            :total-items="totalCount"
            :items-per-page="PER_PAGE"
            current-page-info="REDE.PEOPLE.PAGINATION_INFO"
            @update:current-page="onPageChange"
          />
        </div>
      </template>
    </div>

    <AddPersonDialog
      ref="addDialogRef"
      :projects="store.filterOptions.projects"
      :roles="roles"
      :responsibles="store.filterOptions.responsibles"
      @saved="onSaved"
    />
  </CrmPageShell>
</template>
