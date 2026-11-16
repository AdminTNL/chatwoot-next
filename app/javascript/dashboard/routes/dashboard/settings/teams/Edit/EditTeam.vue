<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useRedeProjectsStore } from 'dashboard/stores/rede/projects';

import TeamForm from '../TeamForm.vue';
import Fronts from './Fronts.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const projectsStore = useRedeProjectsStore();

const isSubmitting = ref(false);
const teamId = computed(() => route.params.teamId);

const getTeam = useMapGetter('teams/getTeam');
const team = computed(() => getTeam.value(teamId.value));
const project = computed(() => projectsStore.getProjectByTeamId(teamId.value));

const formData = computed(() => ({
  name: project.value.name,
  color: project.value.color,
  slug: project.value.slug,
  description: team.value.description,
}));

const showForm = computed(
  () => project.value.id && team.value.id && !projectsStore.uiFlags.fetchingList
);

onMounted(() => {
  projectsStore.get().catch(() => {
    useAlert(t('REDE.PROJECTS.LOAD_ERROR'));
  });
});

const updateProject = async data => {
  isSubmitting.value = true;
  try {
    await projectsStore.update({ id: project.value.id, ...data });
    await store.dispatch('teams/get');
    router.replace({
      name: 'settings_teams_edit_members',
      params: { page: 'edit', teamId: teamId.value },
    });
  } catch (error) {
    useAlert(error?.message || t('TEAMS_SETTINGS.TEAM_FORM.ERROR_MESSAGE'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="h-full w-full p-8 col-span-6 overflow-y-auto">
    <PageHeader
      :header-title="t('TEAMS_SETTINGS.EDIT_FLOW.CREATE.TITLE')"
      :header-content="t('TEAMS_SETTINGS.EDIT_FLOW.CREATE.DESC')"
    />
    <div v-if="showForm" class="flex flex-col gap-8">
      <TeamForm
        :on-submit="updateProject"
        :submit-in-progress="isSubmitting"
        :submit-button-text="t('TEAMS_SETTINGS.EDIT_FLOW.CREATE.BUTTON_TEXT')"
        :form-data="formData"
      />
      <Fronts :project="project" />
    </div>
    <Spinner v-else />
  </div>
</template>
