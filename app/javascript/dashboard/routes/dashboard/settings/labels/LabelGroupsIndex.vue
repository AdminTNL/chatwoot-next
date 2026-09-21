<script setup>
import { useAlert } from 'dashboard/composables';
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { picoSearch } from '@scmmishra/pico-search';

import AddLabelGroup from './AddLabelGroup.vue';
import EditLabelGroup from './EditLabelGroup.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const loading = ref({});
const showAddPopup = ref(false);
const showEditPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const selectedLabelGroup = ref({});
const searchQuery = ref('');

const records = computed(() => getters['labelGroups/getLabelGroups'].value);
const teams = computed(() => getters['teams/getTeams'].value);

const teamNameById = id => {
  const team = teams.value.find(t2 => t2.id === Number(id));
  return team ? team.name : '';
};

const recordsWithTeamName = computed(() =>
  records.value.map(record => ({
    ...record,
    team_name: teamNameById(record.team_id),
  }))
);

const filteredRecords = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return recordsWithTeamName.value;
  return picoSearch(recordsWithTeamName.value, query, [
    { name: 'name', weight: 4 },
    'team_name',
  ]);
});
const uiFlags = computed(() => getters['labelGroups/getUIFlags'].value);

const deleteMessage = computed(() => ` ${selectedLabelGroup.value.name}?`);

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = response => {
  showEditPopup.value = true;
  selectedLabelGroup.value = response;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openDeletePopup = response => {
  showDeleteConfirmationPopup.value = true;
  selectedLabelGroup.value = response;
};
const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteLabelGroup = async id => {
  try {
    await store.dispatch('labelGroups/delete', id);
    useAlert(t('LABEL_GROUP_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.message || t('LABEL_GROUP_MGMT.DELETE.API.ERROR_MESSAGE');
    useAlert(errorMessage);
  } finally {
    loading.value[selectedLabelGroup.value.id] = false;
  }
};

const confirmDeletion = () => {
  loading.value[selectedLabelGroup.value.id] = true;
  closeDeletePopup();
  deleteLabelGroup(selectedLabelGroup.value.id);
};

const tableHeaders = computed(() => {
  return [
    t('LABEL_GROUP_MGMT.LIST.TABLE_HEADER.NAME'),
    t('LABEL_GROUP_MGMT.LIST.TABLE_HEADER.TEAM'),
    t('LABEL_GROUP_MGMT.LIST.TABLE_HEADER.ACTION'),
  ];
});

onBeforeMount(() => {
  store.dispatch('labelGroups/get');
  store.dispatch('teams/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('LABEL_GROUP_MGMT.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('LABEL_GROUP_MGMT.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('LABEL_GROUP_MGMT.HEADER')"
        :description="$t('LABEL_GROUP_MGMT.DESCRIPTION')"
        :search-placeholder="$t('LABEL_GROUP_MGMT.SEARCH_PLACEHOLDER')"
        feature-name="labels"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('LABEL_GROUP_MGMT.COUNT', { n: records.length }) }}
          </span>
        </template>
        <template #actions>
          <router-link
            :to="{ name: 'labels_list' }"
            class="text-sm font-medium text-n-blue-11 hover:underline"
          >
            {{ $t('LABEL_GROUP_MGMT.BACK_TO_LABELS') }}
          </router-link>
          <Button
            :label="$t('LABEL_GROUP_MGMT.HEADER_BTN_TXT')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="
          searchQuery
            ? $t('LABEL_GROUP_MGMT.NO_RESULTS')
            : $t('LABEL_GROUP_MGMT.LIST.404')
        "
      >
        <template #row="{ items }">
          <BaseTableRow
            v-for="labelGroup in items"
            :key="labelGroup.id"
            :item="labelGroup"
          >
            <template #default>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-12">
                  {{ labelGroup.name }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ labelGroup.team_name }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="$t('LABEL_GROUP_MGMT.FORM.EDIT')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    :is-loading="loading[labelGroup.id]"
                    @click="openEditPopup(labelGroup)"
                  />
                  <Button
                    v-tooltip.top="$t('LABEL_GROUP_MGMT.FORM.DELETE')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="loading[labelGroup.id]"
                    @click="openDeletePopup(labelGroup)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddLabelGroup @close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditLabelGroup
        :selected-response="selectedLabelGroup"
        @close="hideEditPopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('LABEL_GROUP_MGMT.DELETE.CONFIRM.TITLE')"
      :message="$t('LABEL_GROUP_MGMT.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="$t('LABEL_GROUP_MGMT.DELETE.CONFIRM.YES')"
      :reject-text="$t('LABEL_GROUP_MGMT.DELETE.CONFIRM.NO')"
    />
  </SettingsLayout>
</template>
