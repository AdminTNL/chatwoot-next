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
  methods: {
    onClose() {
      this.$emit('close');
    },
    async addLabelGroup() {
      try {
        await this.$store.dispatch('labelGroups/create', {
          name: this.name,
          team_id: this.selectedTeamId,
        });
        useAlert(this.$t('LABEL_GROUP_MGMT.ADD.API.SUCCESS_MESSAGE'));
        this.onClose();
      } catch (error) {
        const errorMessage =
          error.message || this.$t('LABEL_GROUP_MGMT.ADD.API.ERROR_MESSAGE');
        useAlert(errorMessage);
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('LABEL_GROUP_MGMT.ADD.TITLE')"
      :header-content="$t('LABEL_GROUP_MGMT.ADD.DESC')"
    />
    <form class="flex flex-wrap mx-0" @submit.prevent="addLabelGroup">
      <woot-input
        v-model="name"
        :class="{ error: v$.name.$error }"
        class="w-full"
        :label="$t('LABEL_GROUP_MGMT.FORM.NAME.LABEL')"
        :placeholder="$t('LABEL_GROUP_MGMT.FORM.NAME.PLACEHOLDER')"
        :error="labelGroupNameErrorMessage"
        data-testid="label-group-name"
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
          data-testid="label-group-submit"
          :label="$t('LABEL_GROUP_MGMT.FORM.CREATE')"
          :disabled="v$.$invalid || uiFlags.isCreating"
          :is-loading="uiFlags.isCreating"
        />
      </div>
    </form>
  </div>
</template>
