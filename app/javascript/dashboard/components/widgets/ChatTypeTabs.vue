<script setup>
import { computed } from 'vue';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  activeTab: {
    type: String,
    default: wootConstants.READ_STATUS_TYPE.UNREAD,
  },
});

const emit = defineEmits(['chatTabChange']);

const activeTabIndex = computed(() => {
  return props.items.findIndex(item => item.key === props.activeTab);
});

const onTabChange = selectedTabIndex => {
  if (selectedTabIndex >= 0 && selectedTabIndex < props.items.length) {
    const selectedItem = props.items[selectedTabIndex];
    if (selectedItem.key !== props.activeTab) {
      emit('chatTabChange', selectedItem.key);
    }
  }
};

const keyboardEvents = {
  'Alt+KeyN': {
    action: () => {
      if (props.activeTab === wootConstants.READ_STATUS_TYPE.ALL) {
        onTabChange(0);
      } else {
        const nextIndex = (activeTabIndex.value + 1) % props.items.length;
        onTabChange(nextIndex);
      }
    },
  },
};

useKeyboardEvents(keyboardEvents);
</script>

<template>
  <ul
    class="grid grid-cols-3 gap-x-2 gap-y-1 w-full px-3 py-2 list-none mb-0 border-b border-b-n-weak"
  >
    <li
      v-for="(item, index) in items"
      :key="item.key"
      class="hover:text-n-slate-12"
    >
      <a
        class="flex items-center justify-center flex-row select-none cursor-pointer relative after:absolute after:bottom-px after:left-0 after:right-0 after:h-[2px] after:rounded-full after:transition-all after:duration-200 text-button text-sm font-medium py-2.5"
        :class="[
          index === activeTabIndex
            ? 'text-n-blue-11 after:bg-n-brand after:opacity-100'
            : 'text-n-slate-11 after:bg-transparent after:opacity-0',
        ]"
        @click="onTabChange(index)"
      >
        {{ item.name }}
        <div
          class="rounded-full h-5 flex items-center justify-center text-xs font-medium my-0 ltr:ml-1 rtl:mr-1 px-1.5 py-0 min-w-[20px]"
          :class="[
            index === activeTabIndex
              ? 'bg-n-blue-3 text-n-blue-11'
              : 'bg-n-alpha-1 text-n-slate-10',
          ]"
        >
          <span>{{ item.count }}</span>
        </div>
      </a>
    </li>
  </ul>
</template>
