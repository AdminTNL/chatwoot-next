<script setup>
import { computed, watch, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';

import LabelItem from 'dashboard/components-next/label/LabelItem.vue';
import AddLabel from 'dashboard/components-next/label/AddLabel.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';

const props = defineProps({
  contactId: {
    type: [String, Number],
    default: null,
  },
});

const store = useStore();
const route = useRoute();

const showDropdown = ref(false);

// Store the currently hovered label's ID
// Using JS state management instead of CSS :hover / group hover
// This will solve the flickering issue when hovering over the last label item
const hoveredLabel = ref(null);

const allLabels = useMapGetter('labels/getLabels');
const contactLabels = useMapGetter('contactLabels/getContactLabels');
const myTeams = useMapGetter('teams/getMyTeams');
const contactTeams = useMapGetter('contactTeams/getTeams');
const contextTeamId = useMapGetter('teamContext/getSelectedTeamId');
const conversationsOfContact = useMapGetter(
  'contactConversations/getContactConversation'
);
const { isAdmin } = useAdmin();

const selectedTeamId = ref(null);

const teamOptions = computed(() => {
  const teamsOfContact = contactTeams.value(props.contactId);
  const teamsForSelector = isAdmin.value
    ? teamsOfContact
    : teamsOfContact.filter(contactTeam =>
        myTeams.value.some(myTeam => myTeam.id === contactTeam.id)
      );

  return teamsForSelector.map(team => ({ value: team.id, label: team.name }));
});

watch(
  teamOptions,
  teams => {
    const isSelectedTeamStillAnOption = teams.some(
      team => team.value === selectedTeamId.value
    );
    if (isSelectedTeamStillAnOption) return;
    const isContextTeamAnOption = teams.some(
      team => team.value === contextTeamId.value
    );
    selectedTeamId.value = isContextTeamAnOption
      ? contextTeamId.value
      : teams[0]?.value || null;
  },
  { immediate: true }
);

const savedLabels = computed(() => {
  const availableContactLabels = contactLabels.value(props.contactId);
  return allLabels.value.filter(({ title }) =>
    availableContactLabels.includes(title)
  );
});

const labelMenuItems = computed(() => {
  return allLabels.value
    .filter(label => label.team_id === selectedTeamId.value)
    .map(label => ({
      label: label.title,
      value: label.id,
      thumbnail: { name: label.title, color: label.color },
      isSelected: savedLabels.value.some(
        savedLabel => savedLabel.id === label.id
      ),
      action: 'contactLabel',
    }))
    .toSorted((a, b) => Number(a.isSelected) - Number(b.isSelected));
});

const fetchLabels = async contactId => {
  if (!contactId) {
    return;
  }
  store.dispatch('contactLabels/get', contactId);
};

const fetchTeams = async contactId => {
  if (!contactId) {
    return;
  }
  store.dispatch('contactTeams/get', contactId);
};

const toggleLabel = async (label, teamId) => {
  try {
    // Base is the full list of contact label titles (including ones the user
    // can't see), since the backend replaces the whole list.
    const currentLabels = [...contactLabels.value(props.contactId)];

    const updatedLabels = currentLabels.includes(label.title)
      ? currentLabels.filter(labelTitle => labelTitle !== label.title)
      : [...currentLabels, label.title];

    await store.dispatch('contactLabels/update', {
      contactId: props.contactId,
      labels: updatedLabels,
      teamId,
    });

    showDropdown.value = false;
  } catch (error) {
    // error
  }
};

const handleLabelAction = ({ value }) => {
  const selectedLabel = allLabels.value.find(label => label.id === value);
  if (!selectedLabel) return Promise.resolve();
  return toggleLabel(selectedLabel, selectedTeamId.value);
};

const handleRemoveLabel = label => {
  return toggleLabel(label, label.team_id ?? null);
};

watch(
  () => conversationsOfContact.value(props.contactId).length,
  () => fetchTeams(props.contactId)
);

watch(
  () => props.contactId,
  (newVal, oldVal) => {
    if (newVal !== oldVal) {
      fetchLabels(newVal);
      fetchTeams(newVal);
    }
  }
);
onMounted(() => {
  store.dispatch('teams/get');
  if (route.params.contactId) {
    fetchLabels(route.params.contactId);
    fetchTeams(route.params.contactId);
  }
});

const handleMouseLeave = () => {
  // Reset hover state when mouse leaves the container
  // This ensures all labels return to their default state
  hoveredLabel.value = null;
};

const handleLabelHover = labelId => {
  // Added this to prevent flickering on when showing remove button on hover
  // If the label item is at end of the line, it will show the remove button
  // when hovering over the last label item
  hoveredLabel.value = labelId;
};
</script>

<template>
  <div class="flex flex-wrap items-center gap-2" @mouseleave="handleMouseLeave">
    <SelectInput
      v-if="teamOptions.length"
      v-model="selectedTeamId"
      class="w-32"
      :options="teamOptions"
    />
    <LabelItem
      v-for="label in savedLabels"
      :key="label.id"
      :label="label"
      :is-hovered="hoveredLabel === label.id"
      @remove="handleRemoveLabel"
      @hover="handleLabelHover(label.id)"
    />
    <AddLabel
      v-if="selectedTeamId !== null"
      :label-menu-items="labelMenuItems"
      @update-label="handleLabelAction"
    />
  </div>
</template>
