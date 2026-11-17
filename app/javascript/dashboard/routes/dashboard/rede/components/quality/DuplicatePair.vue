<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  pair: { type: Object, required: true },
  busy: { type: Boolean, default: false },
});

defineEmits(['dismiss', 'merge']);

const { t } = useI18n();

const people = computed(() => [props.pair.contactA, props.pair.contactB]);

// Data de criação e conversas só aparecem se a API mandar.
const details = person =>
  [
    {
      key: 'phone',
      label: t('REDE.QUALITY.PAIR.PHONE'),
      value: person.phoneNumber,
    },
    { key: 'city', label: t('REDE.QUALITY.PAIR.CITY'), value: person.city },
    {
      key: 'created',
      label: t('REDE.QUALITY.PAIR.CREATED_AT'),
      value: person.createdAt,
    },
    {
      key: 'conversations',
      label: t('REDE.QUALITY.PAIR.CONVERSATIONS'),
      value: person.conversationsCount,
    },
  ].filter(
    item =>
      ['phone', 'city'].includes(item.key) ||
      (item.value !== undefined && item.value !== null)
  );
</script>

<template>
  <div
    class="flex flex-col gap-4 p-4 border rounded-xl border-n-weak bg-n-solid-2"
  >
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
      <div
        v-for="person in people"
        :key="person.id"
        class="flex flex-col gap-1 min-w-0"
      >
        <span class="text-heading-3 text-n-slate-12 truncate">
          {{ person.name || t('REDE.QUALITY.PAIR.NO_NAME') }}
        </span>
        <span
          v-for="item in details(person)"
          :key="item.key"
          class="text-body-main text-n-slate-11"
        >
          {{ item.label }}: {{ item.value || t('REDE.QUALITY.PAIR.EMPTY') }}
        </span>
      </div>
    </div>
    <div class="flex flex-wrap justify-end gap-2">
      <Button
        data-test="dismiss"
        :label="t('REDE.QUALITY.PAIR.DISMISS')"
        slate
        faded
        size="sm"
        :disabled="busy"
        @click="$emit('dismiss', pair)"
      />
      <Button
        data-test="merge"
        :label="t('REDE.QUALITY.PAIR.MERGE')"
        size="sm"
        :disabled="busy"
        @click="$emit('merge', pair)"
      />
    </div>
  </div>
</template>
