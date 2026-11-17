<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  item: { type: Object, required: true },
});

defineEmits(['complete', 'openRecord']);

const { t } = useI18n();

const PROBLEM_KEYS = {
  missing_city: 'REDE.QUALITY.PROBLEM.MISSING_CITY',
  missing_phone: 'REDE.QUALITY.PROBLEM.MISSING_PHONE',
  missing_name: 'REDE.QUALITY.PROBLEM.MISSING_NAME',
  pending_front: 'REDE.QUALITY.PROBLEM.PENDING_FRONT',
};

const problem = computed(() => t(PROBLEM_KEYS[props.item.kind]));
const isPendingFront = computed(() => props.item.kind === 'pending_front');
</script>

<template>
  <div
    class="flex items-center justify-between gap-3 px-4 py-3 border rounded-xl border-n-weak bg-n-solid-2"
  >
    <div class="flex flex-col min-w-0">
      <span class="text-heading-3 text-n-slate-12 truncate">
        {{ item.contact.name || t('REDE.QUALITY.PAIR.NO_NAME') }}
      </span>
      <span class="text-body-main text-n-slate-11">{{ problem }}</span>
    </div>
    <Button
      v-if="isPendingFront"
      data-test="open-record"
      :label="t('REDE.QUALITY.ACTIONS.OPEN_RECORD')"
      slate
      faded
      size="sm"
      @click="$emit('openRecord', item.contact.id)"
    />
    <Button
      v-else
      data-test="complete"
      :label="t('REDE.QUALITY.ACTIONS.COMPLETE')"
      size="sm"
      @click="$emit('complete', item)"
    />
  </div>
</template>
