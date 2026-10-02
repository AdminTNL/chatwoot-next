<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import subDays from 'date-fns/subDays';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import {
  generateReportURLParams,
  parseReportURLParams,
} from '../helpers/reportFilterHelper';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';

defineProps({
  disabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['filterChange']);

const route = useRoute();
const router = useRouter();

const customDateRange = ref([subDays(new Date(), 6), new Date()]);
const selectedDateRange = ref(DATE_RANGE_TYPES.LAST_7_DAYS);
const businessHoursSelected = ref(false);
const selectedTeamId = ref(null);
const teamExplicitlyCleared = ref(false);

const { isAdmin } = useAdmin();
const allTeams = useMapGetter('teams/getTeams');
const myTeams = useMapGetter('teams/getMyTeams');
const contextTeamId = useMapGetter('teamContext/getSelectedTeamId');

const teamOptions = computed(() => {
  const teams = isAdmin.value ? allTeams.value : myTeams.value;
  return (teams || []).map(team => ({ value: team.id, label: team.name }));
});

const teamComboValue = computed(() => selectedTeamId.value ?? '');

const updateURLParams = () => {
  const params = generateReportURLParams({
    from: getUnixStartOfDay(customDateRange.value[0]),
    to: getUnixEndOfDay(customDateRange.value[1]),
    businessHours: businessHoursSelected.value,
    range: selectedDateRange.value,
    team: selectedTeamId.value || (teamExplicitlyCleared.value ? 'all' : null),
  });

  router.replace({ query: { ...params } });
};

const emitChange = () => {
  updateURLParams();
  emit('filterChange', {
    from: getUnixStartOfDay(customDateRange.value[0]),
    to: getUnixEndOfDay(customDateRange.value[1]),
    businessHours: businessHoursSelected.value,
    team: selectedTeamId.value || null,
  });
};

const onDateRangeChange = value => {
  const [startDate, endDate, rangeType] = value;
  customDateRange.value = [startDate, endDate];
  selectedDateRange.value = rangeType || DATE_RANGE_TYPES.CUSTOM_RANGE;
  emitChange();
};

const onBusinessHoursToggle = () => {
  emitChange();
};

const onTeamChange = value => {
  if (value) {
    selectedTeamId.value = Number(value);
  } else {
    selectedTeamId.value = null;
    if (contextTeamId.value || teamExplicitlyCleared.value) {
      teamExplicitlyCleared.value = true;
    }
  }
  emitChange();
};

const initializeFromURL = () => {
  const urlParams = parseReportURLParams(route.query);

  // Set the range type first
  if (urlParams.range) {
    selectedDateRange.value = urlParams.range;
  }

  // Restore dates from URL if available
  if (urlParams.from && urlParams.to) {
    customDateRange.value = [
      new Date(urlParams.from * 1000),
      new Date(urlParams.to * 1000),
    ];
  }

  if (urlParams.businessHours) {
    businessHoursSelected.value = urlParams.businessHours;
  }

  if (typeof urlParams.team === 'number') {
    selectedTeamId.value = urlParams.team;
  } else if (urlParams.team === 'all') {
    selectedTeamId.value = null;
    teamExplicitlyCleared.value = true;
  } else {
    selectedTeamId.value = contextTeamId.value || null;
  }
};

onMounted(() => {
  initializeFromURL();
  emitChange();
});
</script>

<template>
  <div
    class="flex flex-col justify-between gap-3 md:flex-row"
    :class="{ 'pointer-events-none opacity-50': disabled }"
  >
    <div class="flex flex-col flex-wrap items-start gap-2 md:flex-row">
      <WootDatePicker
        v-model:date-range="customDateRange"
        v-model:range-type="selectedDateRange"
        @date-range-changed="onDateRangeChange"
      />
      <ComboBox
        :model-value="teamComboValue"
        :options="teamOptions"
        :placeholder="$t('SUMMARY_REPORTS.TEAM_FILTER.PLACEHOLDER')"
        :search-placeholder="
          $t('SUMMARY_REPORTS.TEAM_FILTER.SEARCH_PLACEHOLDER')
        "
        :empty-state="$t('SUMMARY_REPORTS.TEAM_FILTER.EMPTY')"
        class="w-full md:w-56"
        @update:model-value="onTeamChange"
      />
    </div>
    <div class="flex items-center">
      <span class="mx-2 text-sm whitespace-nowrap">
        {{ $t('REPORT.BUSINESS_HOURS') }}
      </span>
      <span>
        <ToggleSwitch
          v-model="businessHoursSelected"
          @change="onBusinessHoursToggle"
        />
      </span>
    </div>
  </div>
</template>
