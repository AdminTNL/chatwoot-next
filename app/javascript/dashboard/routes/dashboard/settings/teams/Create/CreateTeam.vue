<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { useRedeProjectsStore } from 'dashboard/stores/rede/projects';

import TeamForm from '../TeamForm.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';

const { t } = useI18n();
const router = useRouter();
const store = useStore();
const projectsStore = useRedeProjectsStore();

const isSubmitting = ref(false);

const createProject = async data => {
  isSubmitting.value = true;
  try {
    const project = await projectsStore.create(data);
    // A tela de agentes lê o time da store de times, então ela precisa conhecer o novo.
    await store.dispatch('teams/get');
    router.replace({
      name: 'settings_teams_add_agents',
      params: { page: 'new', teamId: project.teamId },
    });
  } catch (error) {
    useAlert(error?.message || t('TEAMS_SETTINGS.TEAM_FORM.ERROR_MESSAGE'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6 overflow-y-auto">
    <PageHeader
      :header-title="t('TEAMS_SETTINGS.CREATE_FLOW.CREATE.TITLE')"
      :header-content="t('TEAMS_SETTINGS.CREATE_FLOW.CREATE.DESC')"
    />
    <div class="flex flex-wrap">
      <TeamForm
        :on-submit="createProject"
        :submit-in-progress="isSubmitting"
        :submit-button-text="t('TEAMS_SETTINGS.FORM.SUBMIT_CREATE')"
      />
    </div>
  </div>
</template>
