<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import PageHeader from '../SettingsSubPageHeader.vue';

const NO_TEAM = 'none';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const teams = useMapGetter('teams/getTeams');

const selectedTeam = ref(NO_TEAM);
const isSaving = ref(false);

const isNoTeam = computed(() => selectedTeam.value === NO_TEAM);

const teamOptions = computed(() => [
  { value: NO_TEAM, label: t('INBOX_MGMT.ADD.TEAM.NONE') },
  ...teams.value.map(({ id, name }) => ({ value: id, label: name })),
]);

onMounted(() => {
  store.dispatch('teams/get');
});

const saveTeam = async () => {
  isSaving.value = true;
  const inboxId = route.params.inbox_id;

  try {
    await store.dispatch('inboxes/updateInbox', {
      id: inboxId,
      team_id: isNoTeam.value ? null : selectedTeam.value,
    });
    router.replace({
      name: 'settings_inbox_finish',
      params: { page: 'new', inbox_id: inboxId },
    });
  } catch (error) {
    useAlert(error?.message || t('INBOX_MGMT.ADD.TEAM.ERROR_MESSAGE'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <form class="flex flex-wrap flex-col mx-0" @submit.prevent="saveTeam">
      <div class="w-full">
        <PageHeader
          :header-title="t('INBOX_MGMT.ADD.TEAM.TITLE')"
          :header-content="t('INBOX_MGMT.ADD.TEAM.DESC')"
        />
      </div>
      <div>
        <div class="w-full mb-4">
          <label class="mb-0.5 text-sm font-medium text-n-slate-12">
            {{ t('INBOX_MGMT.ADD.TEAM.LABEL') }}
          </label>
          <ComboBox
            v-model="selectedTeam"
            :options="teamOptions"
            :placeholder="t('INBOX_MGMT.ADD.TEAM.PLACEHOLDER')"
          />
          <p
            v-if="isNoTeam"
            data-testid="no-team-warning"
            class="mt-2 mb-0 text-sm text-n-amber-11"
          >
            {{ t('INBOX_MGMT.ADD.TEAM.NO_TEAM_WARNING') }}
          </p>
        </div>
        <div class="w-full">
          <NextButton
            type="submit"
            :is-loading="isSaving"
            solid
            blue
            :label="t('INBOX_MGMT.ADD.TEAM.BUTTON_TEXT')"
          />
        </div>
      </div>
    </form>
  </div>
</template>
