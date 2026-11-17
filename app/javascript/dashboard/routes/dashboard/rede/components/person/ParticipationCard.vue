<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import LastContact from '../people/LastContact.vue';
import ProjectBadge from '../people/ProjectBadge.vue';
import TemperatureBadge from '../people/TemperatureBadge.vue';
import AssignmentRow from './AssignmentRow.vue';
import ContactSearch from './ContactSearch.vue';
import TemperaturePicker from './TemperaturePicker.vue';

// Bloco de uma participação (um projeto). Não fala com a API: emite eventos
// e a página aplica pela store.
const props = defineProps({
  participation: { type: Object, required: true },
  // Frentes do projeto no cadastro: [{ id, name, status, hasTemperature }].
  fronts: { type: Array, default: () => [] },
  roles: { type: Array, default: () => [] },
  responsibles: { type: Array, default: () => [] },
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits([
  'updateParticipation',
  'setTemperature',
  'updateAssignment',
  'close-assignment',
  'createAssignment',
]);

const { t } = useI18n();

const color = computed(() =>
  /^#[0-9a-f]{6}$/i.test(props.participation.project.color || '')
    ? props.participation.project.color
    : '#64748b'
);
// A cor vem do cadastro do projeto, por isso precisa de estilo em linha.
const borderStyle = computed(() => ({ borderLeftColor: color.value }));

const participationClosed = computed(
  () => props.participation.status === 'closed'
);
const projectClosed = computed(
  () => props.participation.project.status === 'closed'
);
// Participação ou projeto encerrado: sem atuações nem temperatura editáveis.
const readonly = computed(
  () => participationClosed.value || projectClosed.value
);
// Responsável e próximo passo seguem editáveis em projeto encerrado (a API aceita).
const metaEditable = computed(() => !participationClosed.value);

const assignments = computed(() => props.participation.assignments || []);
const hasFronts = computed(() => props.participation.project.hasFronts);

const frontById = id => props.fronts.find(front => front.id === id);
// Só frente que aceita temperatura: o front não envia o que a API recusaria.
const frontHasTemperature = assignment =>
  Boolean(frontById(assignment.front?.id)?.hasTemperature);

// --- responsável ---
const responsibleOptions = computed(() => {
  const options = props.responsibles.map(user => ({
    value: user.id,
    label: user.name,
  }));
  const current = props.participation.responsible;
  if (current && !props.responsibles.some(user => user.id === current.id)) {
    options.unshift({
      value: current.id,
      label: t('REDE.PERSON.PARTICIPATION.OUT_OF_PROJECT', {
        name: current.name,
      }),
    });
  }
  return [
    { value: '', label: t('REDE.PERSON.PARTICIPATION.RESPONSIBLE_NONE') },
    ...options,
  ];
});

const updateResponsible = value =>
  emit('updateParticipation', {
    responsibleUserId: value === '' ? null : Number(value),
  });

// --- próximo passo: salva ao sair do campo; erro mantém o texto ---
const nextStep = ref(props.participation.nextStep || '');
watch(
  () => props.participation.nextStep,
  value => {
    nextStep.value = value || '';
  }
);
const saveNextStep = () => {
  const text = nextStep.value.trim();
  if (text === (props.participation.nextStep || '')) return;
  emit('updateParticipation', { nextStep: text });
};

// --- indicado por ---
const changingReferral = ref(false);
const referral = computed(() => {
  const { contact, text } = props.participation.referredBy || {};
  return contact?.name || text || '';
});
// A API aceita uma origem só: ao escolher uma, limpa a outra.
const setReferralContact = contact => {
  changingReferral.value = false;
  emit('updateParticipation', {
    referredByContactId: contact.id,
    referredByText: null,
  });
};
const setReferralText = text => {
  changingReferral.value = false;
  emit('updateParticipation', {
    referredByText: text,
    referredByContactId: null,
  });
};

// --- adicionar atuação / definir frente ---
const adding = ref(false);
const newFrontId = ref('');
const newRoleId = ref('');
const addError = ref('');

const pendingAssignment = computed(() =>
  assignments.value.find(assignment => !assignment.front)
);
const availableFronts = computed(() => {
  const used = new Set(assignments.value.map(item => item.front?.id));
  return props.fronts.filter(
    front => front.status !== 'closed' && !used.has(front.id)
  );
});
const canAdd = computed(
  () =>
    !readonly.value &&
    (availableFronts.value.length > 0 ||
      (!hasFronts.value && assignments.value.length === 0))
);

const frontOptions = computed(() => [
  ...(hasFronts.value
    ? [{ value: '', label: t('REDE.PERSON.ASSIGNMENT.FRONT_PLACEHOLDER') }]
    : []),
  ...availableFronts.value.map(front => ({
    value: front.id,
    label: front.name,
  })),
]);
const roleOptions = computed(() => [
  { value: '', label: t('REDE.PERSON.ASSIGNMENT.ROLE_NONE') },
  ...props.roles.map(role => ({ value: role.id, label: role.name })),
]);

const openAdd = () => {
  adding.value = true;
  newFrontId.value = '';
  newRoleId.value = '';
  addError.value = '';
};

// "Definir frente" numa atuação sem frente a atualiza; senão cria uma nova.
const submitAdd = () => {
  if (hasFronts.value && !newFrontId.value) {
    addError.value = t('REDE.PERSON.ASSIGNMENT.ERRORS.FRONT_REQUIRED');
    return;
  }
  addError.value = '';
  const frontId = newFrontId.value ? Number(newFrontId.value) : undefined;
  const roleId = newRoleId.value ? Number(newRoleId.value) : undefined;
  if (pendingAssignment.value && frontId) {
    emit('updateAssignment', {
      id: pendingAssignment.value.id,
      frontId,
      roleId,
    });
  } else {
    emit('createAssignment', { frontId, roleId });
  }
  adding.value = false;
};
</script>

<template>
  <section
    class="flex flex-col gap-4 p-4 border border-l-4 rounded-xl border-n-weak"
    :class="{ 'opacity-60': participationClosed }"
    :style="borderStyle"
    data-test="participation-card"
  >
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div class="flex flex-wrap items-center gap-2">
        <ProjectBadge :project="participation.project" />
        <span
          v-if="participationClosed"
          class="px-2 py-0.5 text-xs font-medium rounded-md bg-n-alpha-2 text-n-slate-11"
          data-test="closed-label"
        >
          {{ t('REDE.PERSON.PARTICIPATION.CLOSED') }}
        </span>
      </div>
      <div class="flex items-center gap-2 text-sm text-n-slate-11">
        <span>{{ t('REDE.PERSON.PARTICIPATION.LAST_CONTACT') }}</span>
        <LastContact :value="participation.lastContactAt" />
      </div>
    </div>

    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
      <div class="flex flex-col gap-1">
        <span class="text-heading-3 text-n-slate-12">
          {{ t('REDE.PERSON.PARTICIPATION.RESPONSIBLE') }}
        </span>
        <Select
          v-if="metaEditable"
          data-test="responsible-select"
          class="!w-full"
          :model-value="participation.responsible?.id || ''"
          :options="responsibleOptions"
          @update:model-value="updateResponsible"
        />
        <span v-else class="text-sm text-n-slate-11">
          {{
            participation.responsible?.name ||
            t('REDE.PERSON.PARTICIPATION.RESPONSIBLE_NONE')
          }}
        </span>
      </div>

      <div class="flex flex-col gap-1">
        <span class="text-heading-3 text-n-slate-12">
          {{ t('REDE.PERSON.PARTICIPATION.REFERRED_BY') }}
        </span>
        <ContactSearch
          v-if="metaEditable && (changingReferral || !referral)"
          allow-text
          :placeholder="t('REDE.PERSON.PARTICIPATION.REFERRED_PLACEHOLDER')"
          @select="setReferralContact"
          @text="setReferralText"
        />
        <div v-else class="flex items-center gap-2">
          <span class="text-sm text-n-slate-11" data-test="referral">
            {{ referral || t('REDE.PERSON.NONE') }}
          </span>
          <button
            v-if="metaEditable"
            type="button"
            class="text-sm text-n-brand hover:underline"
            data-test="change-referral"
            @click="changingReferral = true"
          >
            {{ t('REDE.PERSON.ASSIGNMENT.CHANGE') }}
          </button>
        </div>
      </div>

      <div class="flex flex-col gap-1 sm:col-span-2">
        <Input
          v-if="metaEditable"
          v-model="nextStep"
          data-test="next-step"
          :label="t('REDE.PERSON.PARTICIPATION.NEXT_STEP')"
          @blur="saveNextStep"
        />
        <template v-else>
          <span class="text-heading-3 text-n-slate-12">
            {{ t('REDE.PERSON.PARTICIPATION.NEXT_STEP') }}
          </span>
          <span class="text-sm text-n-slate-11">
            {{ participation.nextStep || t('REDE.PERSON.NONE') }}
          </span>
        </template>
      </div>
    </div>

    <div
      v-if="!hasFronts"
      class="flex flex-col gap-2"
      data-test="project-temperature"
    >
      <div class="flex items-center gap-2">
        <span class="text-heading-3 text-n-slate-12">
          {{ t('REDE.PERSON.TEMPERATURE.LABEL') }}
        </span>
        <TemperatureBadge :level="participation.projectTemperature" />
      </div>
      <TemperaturePicker
        v-if="!readonly"
        :model-value="participation.projectTemperature"
        :is-loading="isSaving"
        @save="payload => emit('setTemperature', { frontId: null, ...payload })"
      />
    </div>

    <div class="flex flex-col gap-3">
      <div
        v-if="participation.frontPending"
        class="flex flex-wrap items-center justify-between gap-2 px-3 py-2 rounded-lg bg-n-amber-3 text-n-amber-11"
        data-test="front-pending"
      >
        <span class="text-sm font-medium">
          {{ t('REDE.PERSON.ASSIGNMENT.FRONT_PENDING') }}
        </span>
        <Button
          v-if="!readonly"
          data-test="define-front"
          type="button"
          size="xs"
          variant="faded"
          color="amber"
          :label="t('REDE.PERSON.ASSIGNMENT.DEFINE_FRONT')"
          @click="openAdd"
        />
      </div>

      <AssignmentRow
        v-for="assignment in assignments"
        :key="assignment.id"
        :assignment="assignment"
        :roles="roles"
        :has-temperature="frontHasTemperature(assignment)"
        :readonly="readonly"
        :is-loading="isSaving"
        @update="
          patch => emit('updateAssignment', { id: assignment.id, ...patch })
        "
        @close="emit('close-assignment', assignment.id)"
        @set-temperature="payload => emit('setTemperature', payload)"
      />

      <div
        v-if="adding"
        class="flex flex-col gap-2"
        data-test="add-assignment-form"
      >
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <Select
            v-model="newFrontId"
            data-test="new-front"
            class="!w-full"
            :options="frontOptions"
            :error="addError"
          />
          <Select
            v-model="newRoleId"
            data-test="new-role"
            class="!w-full"
            :options="roleOptions"
          />
        </div>
        <p v-if="addError" class="mb-0 text-sm text-n-ruby-11">
          {{ addError }}
        </p>
        <div class="flex gap-2">
          <Button
            data-test="submit-assignment"
            type="button"
            size="sm"
            :label="t('REDE.PERSON.ASSIGNMENT.ADD_CONFIRM')"
            :is-loading="isSaving"
            @click="submitAdd"
          />
          <Button
            type="button"
            size="sm"
            variant="ghost"
            color="slate"
            :label="t('REDE.PERSON.EVENTS.CANCEL')"
            @click="adding = false"
          />
        </div>
      </div>
      <Button
        v-else-if="canAdd"
        data-test="add-assignment"
        type="button"
        size="sm"
        variant="faded"
        color="slate"
        class="self-start"
        icon="i-lucide-plus"
        :label="t('REDE.PERSON.ASSIGNMENT.ADD')"
        @click="openAdd"
      />
    </div>
  </section>
</template>
