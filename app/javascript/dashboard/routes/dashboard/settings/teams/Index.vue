<script setup>
import { computed, onMounted, ref } from 'vue';
import { picoSearch } from '@scmmishra/pico-search';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useRedeProjectsStore } from 'dashboard/stores/rede/projects';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const { t } = useI18n();
const projectsStore = useRedeProjectsStore();

const searchQuery = ref('');
const showClosed = ref(false);
const loading = ref({});
const selectedProject = ref({});
const closeDialogRef = ref(null);

const teams = useMapGetter('teams/getTeams');

// A descrição vive no time; o projeto não a devolve.
const descriptionByTeamId = computed(() =>
  Object.fromEntries(teams.value.map(team => [team.id, team.description]))
);

const projects = computed(() => projectsStore.getProjects);
const visibleProjects = computed(() =>
  showClosed.value
    ? projects.value
    : projects.value.filter(project => project.status !== 'closed')
);

const filteredProjects = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return visibleProjects.value;
  return picoSearch(visibleProjects.value, query, ['name', 'slug']);
});

const isLoading = computed(() => projectsStore.uiFlags.fetchingList);

onMounted(() => {
  projectsStore.get().catch(() => {
    useAlert(t('REDE.PROJECTS.LOAD_ERROR'));
  });
});

const openClose = project => {
  selectedProject.value = project;
  closeDialogRef.value?.open();
};

const runWithLoading = async (project, action, successKey, errorKey) => {
  loading.value[project.id] = true;
  try {
    await action(project.id);
    useAlert(t(successKey));
  } catch (error) {
    useAlert(error?.message || t(errorKey));
  } finally {
    loading.value[project.id] = false;
  }
};

const confirmClose = async () => {
  await runWithLoading(
    selectedProject.value,
    id => projectsStore.close(id),
    'REDE.PROJECTS.CLOSE.SUCCESS',
    'REDE.PROJECTS.CLOSE.ERROR'
  );
  closeDialogRef.value?.close();
};

const reopen = project =>
  runWithLoading(
    project,
    id => projectsStore.reopen(id),
    'REDE.PROJECTS.REOPEN.SUCCESS',
    'REDE.PROJECTS.REOPEN.ERROR'
  );
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="t('TEAMS_SETTINGS.LOADING')"
    :no-records-found="!visibleProjects.length && !searchQuery"
    :no-records-message="t('TEAMS_SETTINGS.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="t('TEAMS_SETTINGS.HEADER')"
        :description="t('TEAMS_SETTINGS.DESCRIPTION')"
        :link-text="t('TEAMS_SETTINGS.LEARN_MORE')"
        :search-placeholder="t('TEAMS_SETTINGS.SEARCH_PLACEHOLDER')"
        feature-name="team_management"
      >
        <template v-if="visibleProjects.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ t('TEAMS_SETTINGS.COUNT', { n: visibleProjects.length }) }}
          </span>
        </template>
        <template #actions>
          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <Checkbox v-model="showClosed" />
            {{ t('REDE.PROJECTS.SHOW_CLOSED') }}
          </label>
          <router-link :to="{ name: 'settings_teams_new' }">
            <Button :label="t('TEAMS_SETTINGS.NEW_TEAM')" size="sm" />
          </router-link>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <span
        v-if="!filteredProjects.length && searchQuery"
        class="flex-1 flex items-center justify-center py-20 text-center text-body-main !text-base text-n-slate-11"
      >
        {{ t('TEAMS_SETTINGS.NO_RESULTS') }}
      </span>

      <div v-else class="divide-y divide-n-weak border-t border-n-weak">
        <div
          v-for="project in filteredProjects"
          :key="project.id"
          class="flex justify-between flex-row items-start gap-4 py-4"
        >
          <div class="flex items-start gap-4">
            <span
              class="mt-1.5 flex-shrink-0 size-4 rounded-full"
              :style="{ backgroundColor: project.color }"
            />
            <div class="flex flex-col items-start gap-1">
              <div class="flex items-center gap-2">
                <span class="block text-heading-3 text-n-slate-12">
                  {{ project.name }}
                </span>
                <span
                  v-if="project.status === 'closed'"
                  class="px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-11"
                >
                  {{ t('REDE.STATUS.CLOSED') }}
                </span>
              </div>
              <p class="mb-0 text-n-slate-11 text-body-main">
                {{ descriptionByTeamId[project.teamId] }}
              </p>
              <p class="mb-0 text-n-slate-11 text-xs">
                {{
                  t(
                    'REDE.PROJECTS.MEMBERS_COUNT',
                    { n: project.membersCount },
                    project.membersCount
                  )
                }}
                ·
                {{
                  t(
                    'REDE.PROJECTS.INBOXES_COUNT',
                    { n: project.inboxesCount },
                    project.inboxesCount
                  )
                }}
              </p>
            </div>
          </div>
          <div class="flex justify-end gap-3">
            <router-link
              :to="{
                name: 'settings_teams_edit',
                params: { teamId: project.teamId },
              }"
            >
              <Button
                v-tooltip.top="t('TEAMS_SETTINGS.LIST.EDIT_TEAM')"
                icon="i-woot-settings"
                slate
                sm
              />
            </router-link>
            <Button
              v-if="project.status === 'closed'"
              :label="t('REDE.ACTIONS.REOPEN')"
              variant="faded"
              color="slate"
              size="sm"
              :is-loading="loading[project.id]"
              @click="reopen(project)"
            />
            <Button
              v-else
              :label="t('REDE.ACTIONS.CLOSE')"
              variant="faded"
              color="slate"
              size="sm"
              :is-loading="loading[project.id]"
              @click="openClose(project)"
            />
          </div>
        </div>
      </div>
    </template>
    <Dialog
      ref="closeDialogRef"
      type="alert"
      :title="t('REDE.PROJECTS.CLOSE.TITLE', { name: selectedProject.name })"
      :description="t('REDE.PROJECTS.CLOSE.MESSAGE')"
      :confirm-button-label="t('REDE.ACTIONS.CLOSE')"
      @confirm="confirmClose"
    />
  </SettingsLayout>
</template>
