<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useRedeOverviewStore } from 'dashboard/stores/rede/overview';
import { useRedeProjectsStore } from 'dashboard/stores/rede/projects';
import { paramsToQuery } from '../helpers/peopleQuery';
import CrmPageShell from '../components/CrmPageShell.vue';
import StatCard from '../components/overview/StatCard.vue';
import TemperatureBars from '../components/overview/TemperatureBars.vue';
import RecentChanges from '../components/overview/RecentChanges.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const overviewStore = useRedeOverviewStore();
const projectsStore = useRedeProjectsStore();

const overview = computed(() => overviewStore.overview || {});
const loadFailed = ref(false);
const projectsLoaded = ref(false);
// Esqueleto também antes da primeira resposta, para não piscar zeros.
const isLoading = computed(
  () =>
    overviewStore.uiFlags.fetchingItem ||
    (overview.value.peopleCount === undefined && !loadFailed.value)
);
const projects = computed(() =>
  projectsStore.getProjects.filter(project => project.status !== 'closed')
);

const projectId = computed(() => {
  const value = Number(
    Array.isArray(route.query.project_id)
      ? route.query.project_id[0]
      : route.query.project_id
  );
  return Number.isInteger(value) && value > 0 ? value : null;
});
const selectedProject = computed(() =>
  projects.value.find(project => project.id === projectId.value)
);

const setProject = id => {
  const { project_id: _ignored, ...rest } = route.query;
  return router.replace({
    query: id ? { ...rest, project_id: String(id) } : rest,
  });
};

const onProjectChange = event => {
  const id = Number(event.target.value);
  router.push({
    query: id ? { ...route.query, project_id: String(id) } : {},
  });
};

// Os filtros vêm prontos da API (um por cartão); sem eles, cai só no projeto.
const fallbackFilters = computed(() =>
  projectId.value ? { project_ids: [projectId.value] } : {}
);
const peopleLink = params => ({
  name: 'rede_people',
  query: paramsToQuery(params),
});
const filtersOf = key => overview.value.filters?.[key] || fallbackFilters.value;

const cards = computed(() => [
  {
    key: 'people',
    label: t('REDE.OVERVIEW.CARDS.PEOPLE'),
    value: overview.value.peopleCount,
    to: peopleLink(filtersOf('people')),
  },
  {
    key: 'front_participations',
    label: t('REDE.OVERVIEW.CARDS.FRONT_PARTICIPATIONS'),
    value: overview.value.frontParticipationsCount,
    to: peopleLink(filtersOf('front_participations')),
  },
  {
    key: 'pending_front',
    label: t('REDE.OVERVIEW.CARDS.PENDING_FRONT'),
    value: overview.value.pendingFrontCount,
    to: peopleLink(filtersOf('pending_front')),
  },
  {
    key: 'no_contact_7d',
    label: t('REDE.OVERVIEW.CARDS.NO_CONTACT_7D'),
    value: overview.value.noContact7dCount,
    to: peopleLink(filtersOf('no_contact_7d')),
    alert: true,
  },
]);

const openTemperature = level => {
  const params = overview.value.filters?.by_temperature?.[level] || {
    ...fallbackFilters.value,
    temperatures: [level],
  };
  router.push(peopleLink(params));
};

const load = async () => {
  // Projeto fora do escopo (a API responderia 404): limpa o filtro e avisa.
  if (projectsLoaded.value && projectId.value && !selectedProject.value) {
    useAlert(t('REDE.OVERVIEW.OUT_OF_SCOPE'));
    await setProject(null);
    return;
  }
  loadFailed.value = false;
  try {
    await overviewStore.get(projectId.value);
  } catch (error) {
    loadFailed.value = true;
    useAlert(t('REDE.OVERVIEW.LOAD_ERROR'));
  }
};

onMounted(async () => {
  try {
    await projectsStore.get();
    projectsLoaded.value = true;
  } catch (error) {
    // Sem a lista, não valida o projeto da URL: a API decide.
  }
  load();
});

watch(projectId, (current, previous) => {
  if (current !== previous) load();
});
</script>

<template>
  <CrmPageShell
    :title="t('REDE.CRM.OVERVIEW.TITLE')"
    :description="t('REDE.CRM.OVERVIEW.DESCRIPTION')"
  >
    <div class="flex flex-col gap-6">
      <div class="flex items-center gap-2">
        <label
          for="rede-overview-project"
          class="text-label text-n-slate-11 shrink-0"
        >
          {{ t('REDE.OVERVIEW.PROJECT_SELECT') }}
        </label>
        <span
          v-if="selectedProject"
          class="inline-block rounded-full size-3 shrink-0"
          :style="{ backgroundColor: selectedProject.color }"
        />
        <select
          id="rede-overview-project"
          class="!mb-0 max-w-xs"
          :value="projectId || ''"
          @change="onProjectChange"
        >
          <option value="">{{ t('REDE.OVERVIEW.ALL_PROJECTS') }}</option>
          <option
            v-for="project in projects"
            :key="project.id"
            :value="project.id"
          >
            {{ project.name }}
          </option>
        </select>
      </div>

      <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard
          v-for="card in cards"
          :key="card.key"
          :label="card.label"
          :value="card.value || 0"
          :to="card.to"
          :alert="card.alert"
          :loading="isLoading"
        />
      </div>

      <section class="flex flex-col gap-3">
        <h2 class="mb-0 text-heading-2 text-n-slate-12">
          {{ t('REDE.OVERVIEW.BY_TEMPERATURE.TITLE') }}
        </h2>
        <p class="mb-0 text-label text-n-slate-11">
          {{ t('REDE.OVERVIEW.BY_TEMPERATURE.HINT') }}
        </p>
        <TemperatureBars
          :counts="overview.byTemperature || {}"
          @select="openTemperature"
        />
      </section>

      <section class="flex flex-col gap-3">
        <h2 class="mb-0 text-heading-2 text-n-slate-12">
          {{ t('REDE.OVERVIEW.RECENT.TITLE') }}
        </h2>
        <RecentChanges :changes="overview.recentChanges || []" />
      </section>
    </div>
  </CrmPageShell>
</template>
