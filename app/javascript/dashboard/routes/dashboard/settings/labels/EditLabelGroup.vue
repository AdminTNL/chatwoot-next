<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import validations, {
  getLabelGroupNameErrorMessage,
  getLabelGroupTeamErrorMessage,
} from './labelGroupValidations';
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
      name: '',
      selectedTeamId: '',
    };
  },
  validations,
  computed: {
    ...mapGetters({
      uiFlags: 'labelGroups/getUIFlags',
      teams: 'teams/getTeams',
    }),
    pageTitle() {
      return `${this.$t('LABEL_GROUP_MGMT.EDIT.TITLE')} - ${
        this.selectedResponse.name
      }`;
    },
    labelGroupNameErrorMessage() {
      const errorMessage = getLabelGroupNameErrorMessage(this.v$);
      return this.$t(errorMessage);
    },
    labelGroupTeamErrorMessage() {
      const errorMessage = getLabelGroupTeamErrorMessage(this.v$);
      return this.$t(errorMessage);
    },
    teamOptions() {
      return this.teams.map(team => ({ value: team.id, label: team.name }));
    },
  },
  mounted() {
    this.setFormValues();
  },
  methods: {
    onClose() {
      this.$emit('close');
    },
    setFormValues() {
      this.name = this.selectedResponse.name;
      this.selectedTeamId = this.selectedResponse.team_id || '';
    },
    editLabelGroup() {
      this.$store
        .dispatch('labelGroups/update', {
          id: this.selectedResponse.id,
          name: this.name,
          team_id: this.selectedTeamId,
        })
        .then(() => {
          useAlert(this.$t('LABEL_GROUP_MGMT.EDIT.API.SUCCESS_MESSAGE'));
          setTimeout(() => this.onClose(), 10);
        })
        .catch(() => {
          useAlert(this.$t('LABEL_GROUP_MGMT.EDIT.API.ERROR_MESSAGE'));
        });
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header :header-title="pageTitle" />
    <form class="flex flex-wrap mx-0" @submit.prevent="editLabelGroup">
      <woot-input
        v-model="name"
        :class="{ error: v$.name.$error }"
        class="w-full"
        :label="$t('LABEL_GROUP_MGMT.FORM.NAME.LABEL')"
        :placeholder="$t('LABEL_GROUP_MGMT.FORM.NAME.PLACEHOLDER')"
        :error="labelGroupNameErrorMessage"
        @input="v$.name.$touch"
        @blur="v$.name.$touch"
      />

      <div class="w-full">
        <label>
          {{ $t('LABEL_GROUP_MGMT.FORM.TEAM.LABEL') }}
          <SelectInput
            v-model="selectedTeamId"
            :options="teamOptions"
            :placeholder="$t('LABEL_GROUP_MGMT.FORM.TEAM.PLACEHOLDER')"
            :error="labelGroupTeamErrorMessage"
            @update:model-value="v$.selectedTeamId.$touch"
          />
        </label>
      </div>
      <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
        <NextButton
          faded
          slate
          type="reset"
          :label="$t('LABEL_GROUP_MGMT.FORM.CANCEL')"
          @click.prevent="onClose"
        />
        <NextButton
          type="submit"
          :label="$t('LABEL_GROUP_MGMT.FORM.EDIT')"
          :disabled="v$.$invalid || uiFlags.isUpdating"
          :is-loading="uiFlags.isUpdating"
        />
      </div>
    </form>
  </div>
</template>
