<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TemperatureBadge from '../people/TemperatureBadge.vue';
import ContactSearch from './ContactSearch.vue';
import TemperaturePicker from './TemperaturePicker.vue';

// Uma atuação ativa: frente, papel, superior e temperatura (só em frente
// com has_temperature). Não fala com a API: emite os eventos para a ficha.
const props = defineProps({
  assignment: { type: Object, required: true },
  roles: { type: Array, default: () => [] },
  // A frente aceita temperatura? Vem do cadastro da frente, não da ficha.
  hasTemperature: { type: Boolean, default: false },
  readonly: { type: Boolean, default: false },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['update', 'close', 'setTemperature']);

const { t } = useI18n();

const changingSuperior = ref(false);

const roleOptions = computed(() => [
  { value: '', label: t('REDE.PERSON.ASSIGNMENT.ROLE_NONE') },
  ...props.roles.map(role => ({ value: role.id, label: role.name })),
]);

const updateRole = value =>
  emit('update', { roleId: value === '' ? null : Number(value) });

const updateSuperior = contact => {
  changingSuperior.value = false;
  emit('update', { superiorContactId: contact.id });
};

const setTemperature = ({ level, note }) =>
  emit('setTemperature', {
    frontId: props.assignment.front?.id ?? null,
    level,
    note,
  });
</script>

<template>
  <div
    class="flex flex-col gap-2 p-3 border rounded-lg border-n-weak"
    data-test="assignment-row"
  >
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ assignment.front?.name || t('REDE.PERSON.ASSIGNMENT.NO_FRONT') }}
        </span>
        <TemperatureBadge
          v-if="hasTemperature"
          :level="assignment.temperature"
        />
      </div>
      <Button
        v-if="!readonly"
        data-test="close-assignment"
        type="button"
        size="xs"
        variant="ghost"
        color="ruby"
        :label="t('REDE.PERSON.ASSIGNMENT.CLOSE')"
        :is-loading="isLoading"
        @click="emit('close')"
      />
    </div>

    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
      <div class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-11">
          {{ t('REDE.PERSON.ASSIGNMENT.ROLE') }}
        </span>
        <Select
          v-if="!readonly"
          data-test="role-select"
          class="!w-full"
          :model-value="assignment.role?.id || ''"
          :options="roleOptions"
          @update:model-value="updateRole"
        />
        <span v-else class="text-sm text-n-slate-12">
          {{ assignment.role?.name || t('REDE.PERSON.ASSIGNMENT.ROLE_NONE') }}
        </span>
      </div>

      <div class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-11">
          {{ t('REDE.PERSON.ASSIGNMENT.SUPERIOR') }}
        </span>
        <ContactSearch
          v-if="!readonly && (changingSuperior || !assignment.superior)"
          :placeholder="t('REDE.PERSON.ASSIGNMENT.SUPERIOR_PLACEHOLDER')"
          @select="updateSuperior"
        />
        <div v-else class="flex items-center gap-2">
          <span class="text-sm text-n-slate-12" data-test="superior-name">
            {{ assignment.superior?.name || t('REDE.PERSON.NONE') }}
          </span>
          <button
            v-if="!readonly"
            type="button"
            class="text-sm text-n-brand hover:underline"
            data-test="change-superior"
            @click="changingSuperior = true"
          >
            {{ t('REDE.PERSON.ASSIGNMENT.CHANGE') }}
          </button>
        </div>
      </div>
    </div>

    <TemperaturePicker
      v-if="hasTemperature && !readonly"
      :model-value="assignment.temperature"
      :is-loading="isLoading"
      @save="setTemperature"
    />
  </div>
</template>
