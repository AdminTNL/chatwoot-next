<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  label: {
    type: String,
    required: true,
  },
});

const emit = defineEmits(['change']);
const modelValue = defineModel({
  type: String,
  default: null,
});

const MENU_ITEM_TYPES = {
  VISIBILITY: 'visibility',
};

const MENU_ACTIONS = {
  SELECT: 'select',
};

const { t } = useI18n();
const [showDropdown, toggleDropdown] = useToggle();

const visibilityOptions = computed(() => [
  {
    label: t('SEARCH.FILTERS.VISIBILITY_OPTIONS.PUBLIC'),
    value: 'public',
    action: MENU_ACTIONS.SELECT,
    type: MENU_ITEM_TYPES.VISIBILITY,
    isSelected: modelValue.value === 'public',
  },
  {
    label: t('SEARCH.FILTERS.VISIBILITY_OPTIONS.PRIVATE_NOTE'),
    value: 'private_note',
    action: MENU_ACTIONS.SELECT,
    type: MENU_ITEM_TYPES.VISIBILITY,
    isSelected: modelValue.value === 'private_note',
  },
  {
    label: t('SEARCH.FILTERS.VISIBILITY_OPTIONS.AI_SUGGESTION'),
    value: 'ai_suggestion',
    action: MENU_ACTIONS.SELECT,
    type: MENU_ITEM_TYPES.VISIBILITY,
    isSelected: modelValue.value === 'ai_suggestion',
  },
]);

const menuSections = computed(() => {
  return [
    {
      title: props.label,
      items: visibilityOptions.value,
    },
  ];
});

const selectedLabel = computed(() => {
  if (!modelValue.value) return props.label;

  const option = visibilityOptions.value.find(
    item => item.value === modelValue.value
  );
  if (option) return `${props.label}: ${option.label}`;

  return `${props.label}: ${modelValue.value}`;
});

const handleAction = item => {
  if (modelValue.value === item.value) {
    modelValue.value = null;
  } else {
    modelValue.value = item.value;
  }
  toggleDropdown(false);
  emit('change');
};
</script>

<template>
  <div
    v-on-click-outside="() => toggleDropdown(false)"
    class="relative flex items-center group min-w-0 max-w-full"
  >
    <Button
      sm
      :variant="showDropdown ? 'faded' : 'ghost'"
      slate
      :label="selectedLabel"
      trailing-icon
      icon="i-lucide-chevron-down"
      class="!px-2 max-w-full"
      @click="toggleDropdown()"
    />
    <DropdownMenu
      v-if="showDropdown"
      :menu-sections="menuSections"
      class="mt-1 ltr:right-0 rtl:left-0 top-full w-64 max-h-80"
      @action="handleAction"
    />
  </div>
</template>
