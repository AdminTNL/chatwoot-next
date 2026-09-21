<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import validations, {
  getLabelTitleErrorMessage,
  getLabelTeamErrorMessage,
  getLabelGroupErrorMessage,
} from './validations';
import { useVuelidate } from '@vuelidate/core';

import NextButton from 'dashboard/components-next/button/Button.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';

export default {
  components: {
    NextButton,
    SelectInput,
  },
  props: {
    selectedResponse: {
      type: Object,
      default: () => {},
    },
  },
  emits: ['close'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      title: '',
      description: '',
      showOnSidebar: true,
      color: '',
      selectedTeamId: '',
      selectedLabelGroupId: '',
    };
  },
  validations,
  computed: {
    ...mapGetters({
      uiFlags: 'labels/getUIFlags',
      teams: 'teams/getTeams',
      labelGroups: 'labelGroups/getLabelGroups',
    }),
    pageTitle() {
      return `${this.$t('LABEL_MGMT.EDIT.TITLE')} - ${
        this.selectedResponse.title
      }`;
    },
    labelTitleErrorMessage() {
      const errorMessage = getLabelTitleErrorMessage(this.v$);
      return this.$t(errorMessage);
    },
    labelTeamErrorMessage() {
      const errorMessage = getLabelTeamErrorMessage(this.v$);
      return this.$t(errorMessage);
    },
    labelGroupErrorMessage() {
      const errorMessage = getLabelGroupErrorMessage(this.v$);
      return this.$t(errorMessage);
    },
    teamOptions() {
      return this.teams.map(team => ({ value: team.id, label: team.name }));
    },
    selectedTeam() {
      return this.teams.find(team => team.id === this.selectedTeamId);
    },
    teamLabelPrefix() {
      return this.selectedTeam ? this.selectedTeam.label_prefix : '';
    },
    labelGroupOptions() {
      return this.labelGroups
        .filter(labelGroup => labelGroup.team_id === this.selectedTeamId)
        .map(labelGroup => ({ value: labelGroup.id, label: labelGroup.name }));
    },
  },
  watch: {
    selectedTeamId(newTeamId, oldTeamId) {
      const oldTeam = this.teams.find(team => team.id === oldTeamId);
      if (oldTeam) {
        const oldPrefix = `${oldTeam.label_prefix}-`;
        if (oldPrefix.length > 1 && this.title.startsWith(oldPrefix)) {
          this.title = this.title.slice(oldPrefix.length);
        }
      }

      const isSelectedLabelGroupInNewTeam = this.labelGroups.some(
        labelGroup =>
          labelGroup.id === this.selectedLabelGroupId &&
          labelGroup.team_id === newTeamId
      );
      if (!isSelectedLabelGroupInNewTeam) {
        this.selectedLabelGroupId = '';
      }
    },
  },
  mounted() {
    this.$store.dispatch('labelGroups/get');
    this.setFormValues();
  },
  methods: {
    onClose() {
      this.$emit('close');
    },
    setFormValues() {
      this.description = this.selectedResponse.description;
      this.showOnSidebar = this.selectedResponse.show_on_sidebar;
      this.color = this.selectedResponse.color;
      this.selectedTeamId = this.selectedResponse.team_id || '';
      this.selectedLabelGroupId = this.selectedResponse.label_group_id || '';

      const fullTitle = this.selectedResponse.title || '';
      const currentPrefix = this.teamLabelPrefix
        ? `${this.teamLabelPrefix}-`
        : '';
      this.title =
        currentPrefix && fullTitle.startsWith(currentPrefix)
          ? fullTitle.slice(currentPrefix.length)
          : fullTitle;
    },
    editLabel() {
      this.$store
        .dispatch('labels/update', {
          id: this.selectedResponse.id,
          color: this.color,
          description: this.description,
          title: this.title.toLowerCase(),
          show_on_sidebar: this.showOnSidebar,
          team_id: this.selectedTeamId,
          label_group_id: this.selectedLabelGroupId || null,
        })
        .then(() => {
          useAlert(this.$t('LABEL_MGMT.EDIT.API.SUCCESS_MESSAGE'));
          setTimeout(() => this.onClose(), 10);
        })
        .catch(() => {
          useAlert(this.$t('LABEL_MGMT.EDIT.API.ERROR_MESSAGE'));
        });
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header :header-title="pageTitle" />
    <form class="flex flex-wrap mx-0" @submit.prevent="editLabel">
      <woot-input
        v-model="title"
        :class="{ error: v$.title.$error }"
        class="w-full label-name--input"
        :label="$t('LABEL_MGMT.FORM.NAME.LABEL')"
        :placeholder="$t('LABEL_MGMT.FORM.NAME.PLACEHOLDER')"
        :error="labelTitleErrorMessage"
        @input="v$.title.$touch"
        @blur="v$.title.$touch"
      />
      <woot-input
        v-model="description"
        :class="{ error: v$.description.$error }"
        class="w-full"
        :label="$t('LABEL_MGMT.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('LABEL_MGMT.FORM.DESCRIPTION.PLACEHOLDER')"
        @input="v$.description.$touch"
        @blur="v$.description.$touch"
      />

      <div class="w-full">
        <label>
          {{ $t('LABEL_MGMT.FORM.COLOR.LABEL') }}
          <woot-color-picker v-model="color" />
        </label>
      </div>
      <div class="flex items-center w-full gap-2">
        <input v-model="showOnSidebar" type="checkbox" :value="true" />
        <label for="conversation_creation">
          {{ $t('LABEL_MGMT.FORM.SHOW_ON_SIDEBAR.LABEL') }}
        </label>
      </div>

      <div class="w-full">
        <label>
          {{ $t('LABEL_MGMT.FORM.TEAM.LABEL') }}
          <SelectInput
            v-model="selectedTeamId"
            :options="teamOptions"
            :placeholder="$t('LABEL_MGMT.FORM.TEAM.PLACEHOLDER')"
            :error="labelTeamErrorMessage"
            @update:model-value="v$.selectedTeamId.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label>
          {{ $t('LABEL_MGMT.FORM.LABEL_GROUP.LABEL') }}
          <SelectInput
            v-model="selectedLabelGroupId"
            :options="labelGroupOptions"
            :placeholder="$t('LABEL_MGMT.FORM.LABEL_GROUP.PLACEHOLDER')"
            :error="labelGroupErrorMessage"
            @update:model-value="v$.selectedLabelGroupId.$touch"
          />
        </label>
      </div>
      <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
        <NextButton
          faded
          slate
          type="reset"
          :label="$t('LABEL_MGMT.FORM.CANCEL')"
          @click.prevent="onClose"
        />
        <NextButton
          type="submit"
          :label="$t('LABEL_MGMT.FORM.EDIT')"
          :disabled="v$.$invalid || uiFlags.isUpdating"
          :is-loading="uiFlags.isUpdating"
        />
      </div>
    </form>
  </div>
</template>

<style lang="scss" scoped>
// Label API supports only lowercase letters
.label-name--input {
  :deep(input) {
    @apply lowercase;
  }
}
</style>
