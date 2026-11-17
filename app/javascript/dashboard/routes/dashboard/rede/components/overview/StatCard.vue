<script setup>
import { computed } from 'vue';

const props = defineProps({
  label: { type: String, required: true },
  value: { type: Number, default: 0 },
  to: { type: Object, default: null },
  alert: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const isAlert = computed(() => props.alert && props.value > 0);
</script>

<template>
  <component
    :is="to ? 'RouterLink' : 'div'"
    :to="to || undefined"
    :data-alert="String(isAlert)"
    class="flex flex-col gap-2 p-4 border rounded-xl outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
    :class="[
      isAlert ? 'border-n-ruby-6 bg-n-ruby-2' : 'border-n-weak bg-n-solid-2',
      to ? 'hover:bg-n-alpha-1' : '',
    ]"
  >
    <span
      class="text-label"
      :class="isAlert ? 'text-n-ruby-11' : 'text-n-slate-11'"
    >
      {{ label }}
    </span>
    <span
      v-if="loading"
      data-test="skeleton"
      class="w-16 h-8 rounded animate-pulse bg-n-alpha-2"
    />
    <span
      v-else
      class="text-heading-1 tabular-nums"
      :class="isAlert ? 'text-n-ruby-11' : 'text-n-slate-12'"
    >
      {{ value }}
    </span>
  </component>
</template>
