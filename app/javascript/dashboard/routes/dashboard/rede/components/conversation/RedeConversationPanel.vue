<script setup>
import { computed, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import camelcaseKeys from 'camelcase-keys';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import PeopleAPI from 'dashboard/api/rede/people';
import ProjectsAPI from 'dashboard/api/rede/projects';
import ParticipationsAPI from 'dashboard/api/rede/participations';
import InteractionsAPI from 'dashboard/api/rede/interactions';
import EvaluationsAPI from 'dashboard/api/rede/evaluations';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import LastContact from '../people/LastContact.vue';
import ProjectBadge from '../people/ProjectBadge.vue';
import TemperatureBadge from '../people/TemperatureBadge.vue';
import CallDialog from '../person/CallDialog.vue';
import NoteDialog from '../person/NoteDialog.vue';
import TemperaturePicker from '../person/TemperaturePicker.vue';

// Painel "CRM" da conversa. O projeto vem sempre do time da conversa
// (teamId), nunca de uma escolha livre. Fala com a API direto, sem a store da
// ficha, para o painel não disputar estado com a página da pessoa.
const props = defineProps({
  conversationId: { type: [Number, String], default: null },
  contactId: { type: Number, default: null },
  teamId: { type: Number, default: null },
});

const { t } = useI18n();
const router = useRouter();
const currentUser = useMapGetter('getCurrentUser');

// 'loading' | 'ready' | 'error' | 'noProject'
const status = ref('loading');
const project = ref(null);
const participation = ref(null);
const isSaving = ref(false);
const dialogError = ref('');
const nextStep = ref('');
const callDialog = ref(null);
const noteDialog = ref(null);

// Cada carga ganha um número: resposta de carga mais antiga é descartada.
let sequence = 0;

const isClosed = computed(
  () =>
    project.value?.status === 'closed' ||
    participation.value?.status === 'closed'
);
const fronts = computed(() => project.value?.fronts || []);
const activeFronts = computed(() =>
  fronts.value.filter(front => front.status !== 'closed')
);
const hasFronts = computed(() =>
  Boolean(participation.value?.project.hasFronts)
);
// Só atuações com frente: "frente a definir" tem aviso próprio.
const frontAssignments = computed(() =>
  (participation.value?.assignments || []).filter(item => item.front)
);
const dialogProjects = computed(() =>
  project.value ? [{ id: project.value.id, name: project.value.name }] : []
);
const frontsByProject = computed(() =>
  project.value ? { [project.value.id]: activeFronts.value } : {}
);

const frontHasTemperature = assignment =>
  Boolean(
    fronts.value.find(front => front.id === assignment.front?.id)
      ?.hasTemperature
  );

const fetchPerson = async () => {
  try {
    const { data } = await PeopleAPI.show(props.contactId);
    return camelcaseKeys(data || {}, {
      deep: true,
      stopPaths: ['contact.custom_attributes', 'contact.additional_attributes'],
    });
  } catch (error) {
    // 404: sem participação visível, ou seja, a pessoa está fora do projeto.
    if (error?.response?.status === 404) return null;
    throw error;
  }
};

const load = async ({ silent = false } = {}) => {
  sequence += 1;
  const current = sequence;
  if (!props.teamId) {
    project.value = null;
    participation.value = null;
    status.value = 'noProject';
    return;
  }
  if (!silent) {
    status.value = 'loading';
    project.value = null;
    participation.value = null;
  }
  try {
    const [projectsResponse, person] = await Promise.all([
      ProjectsAPI.get(),
      fetchPerson(),
    ]);
    if (current !== sequence) return;
    const found = camelcaseKeys(projectsResponse.data || [], {
      deep: true,
    }).find(item => item.teamId === props.teamId);
    project.value = found || null;
    participation.value = found
      ? (person?.participations || []).find(
          item => item.project.teamId === props.teamId
        ) || null
      : null;
    nextStep.value = participation.value?.nextStep || '';
    status.value = found ? 'ready' : 'noProject';
  } catch (error) {
    if (current !== sequence) return;
    status.value = 'error';
  }
};

watch(
  () => [props.conversationId, props.contactId, props.teamId],
  () => load(),
  { immediate: true }
);

// Roda a mutação e recarrega o painel; falha vira alerta e mantém o painel.
const perform = async action => {
  isSaving.value = true;
  try {
    await action();
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        error?.message ||
        t('REDE.PERSON.GENERIC_ERROR')
    );
    return false;
  } finally {
    isSaving.value = false;
  }
  await load({ silent: true });
  return true;
};

const addToProject = () =>
  perform(() =>
    ParticipationsAPI.create({
      project_id: project.value.id,
      contact_id: props.contactId,
    })
  );

const saveNextStep = () => {
  const text = nextStep.value.trim();
  if (text === (participation.value.nextStep || '')) return;
  perform(() =>
    ParticipationsAPI.update(participation.value.id, { next_step: text })
  );
};

const saveTemperature = (frontId, { level, note }) =>
  perform(() =>
    EvaluationsAPI.create({
      project_id: project.value.id,
      contact_id: props.contactId,
      front_id: frontId,
      level,
      note,
    })
  );

const openDialog = dialog => {
  dialogError.value = '';
  dialog.value?.open();
};

const registerInteraction = async (kind, dialog, payload) => {
  const { frontId, answered, summary, occurredAt } = payload;
  dialogError.value = '';
  isSaving.value = true;
  try {
    await InteractionsAPI.create({
      project_id: project.value.id,
      contact_id: props.contactId,
      front_id: frontId,
      kind,
      answered,
      summary,
      occurred_at: occurredAt,
    });
  } catch (error) {
    dialogError.value =
      error?.response?.data?.error ||
      error?.message ||
      t('REDE.PERSON.GENERIC_ERROR');
    return;
  } finally {
    isSaving.value = false;
  }
  dialog.value?.close();
  await load({ silent: true });
};

const openProfile = () =>
  router.push({ name: 'rede_person', params: { contactId: props.contactId } });
</script>

<template>
  <div class="flex flex-col gap-3 p-3 text-sm" data-test="crm-panel">
    <div v-if="status === 'loading'" class="flex justify-center py-4">
      <Spinner />
    </div>

    <div
      v-else-if="status === 'error'"
      class="flex flex-col items-start gap-2"
      data-test="crm-error"
    >
      <p class="mb-0 text-n-ruby-11">{{ t('REDE.CONVERSATION.LOAD_ERROR') }}</p>
      <Button
        data-test="crm-retry"
        type="button"
        size="sm"
        variant="faded"
        color="slate"
        :label="t('REDE.CONVERSATION.RETRY')"
        @click="load()"
      />
    </div>

    <p
      v-else-if="status === 'noProject'"
      class="mb-0 text-n-slate-11"
      data-test="crm-no-project"
    >
      {{ t('REDE.CONVERSATION.NO_PROJECT') }}
    </p>

    <div
      v-else-if="!participation"
      class="flex flex-col items-start gap-2"
      data-test="crm-outside"
    >
      <p class="mb-0 text-n-slate-11">
        {{ t('REDE.CONVERSATION.OUTSIDE', { name: project.name }) }}
      </p>
      <Button
        v-if="project.status !== 'closed'"
        data-test="crm-add"
        type="button"
        size="sm"
        :label="t('REDE.CONVERSATION.ADD_TO_PROJECT')"
        :is-loading="isSaving"
        @click="addToProject"
      />
    </div>

    <div v-else class="flex flex-col gap-3" data-test="crm-participating">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <ProjectBadge :project="project" />
        <div class="flex items-center gap-2 text-n-slate-11">
          <span>{{ t('REDE.PERSON.PARTICIPATION.LAST_CONTACT') }}</span>
          <LastContact :value="participation.lastContactAt" />
        </div>
      </div>

      <div
        v-if="participation.frontPending"
        class="px-3 py-2 font-medium rounded-lg bg-n-amber-3 text-n-amber-11"
        data-test="front-pending"
      >
        {{ t('REDE.PERSON.ASSIGNMENT.FRONT_PENDING') }}
      </div>

      <div
        v-if="!hasFronts"
        class="flex flex-col gap-2"
        data-test="project-temperature"
      >
        <div class="flex items-center gap-2">
          <span class="text-n-slate-12">
            {{ t('REDE.PERSON.TEMPERATURE.LABEL') }}
          </span>
          <TemperatureBadge :level="participation.projectTemperature" />
        </div>
        <TemperaturePicker
          v-if="!isClosed"
          :model-value="participation.projectTemperature"
          :is-loading="isSaving"
          @save="payload => saveTemperature(null, payload)"
        />
      </div>

      <div
        v-for="assignment in frontAssignments"
        :key="assignment.id"
        class="flex flex-col gap-2"
        data-test="crm-assignment"
      >
        <div class="flex items-center gap-2">
          <span class="font-medium text-n-slate-12">
            {{ assignment.front?.name }}
          </span>
          <TemperatureBadge
            v-if="frontHasTemperature(assignment)"
            :level="assignment.temperature"
          />
        </div>
        <TemperaturePicker
          v-if="frontHasTemperature(assignment) && !isClosed"
          :model-value="assignment.temperature"
          :is-loading="isSaving"
          @save="payload => saveTemperature(assignment.front.id, payload)"
        />
      </div>

      <div class="flex items-center gap-2">
        <span class="text-n-slate-12">
          {{ t('REDE.PERSON.PARTICIPATION.RESPONSIBLE') }}
        </span>
        <span class="text-n-slate-11">
          {{
            participation.responsible?.name ||
            t('REDE.PERSON.PARTICIPATION.RESPONSIBLE_NONE')
          }}
        </span>
      </div>

      <Input
        v-model="nextStep"
        data-test="next-step"
        :label="t('REDE.PERSON.PARTICIPATION.NEXT_STEP')"
        :disabled="participation.status === 'closed'"
        @blur="saveNextStep"
      />

      <div class="flex flex-wrap gap-2">
        <Button
          v-if="!isClosed"
          data-test="crm-call"
          type="button"
          size="sm"
          variant="faded"
          color="slate"
          :label="t('REDE.PERSON.HEADER.REGISTER_CALL')"
          @click="openDialog(callDialog)"
        />
        <Button
          v-if="!isClosed"
          data-test="crm-note"
          type="button"
          size="sm"
          variant="faded"
          color="slate"
          :label="t('REDE.PERSON.HEADER.ADD_NOTE')"
          @click="openDialog(noteDialog)"
        />
        <Button
          data-test="crm-open-profile"
          type="button"
          size="sm"
          variant="ghost"
          color="slate"
          :label="t('REDE.CONVERSATION.OPEN_PROFILE')"
          @click="openProfile"
        />
      </div>

      <CallDialog
        ref="callDialog"
        :projects="dialogProjects"
        :fronts-by-project="frontsByProject"
        :author-name="currentUser?.name || ''"
        :is-loading="isSaving"
        :error-message="dialogError"
        @submit="payload => registerInteraction('call', callDialog, payload)"
      />
      <NoteDialog
        ref="noteDialog"
        :projects="dialogProjects"
        :fronts-by-project="frontsByProject"
        :is-loading="isSaving"
        :error-message="dialogError"
        @submit="payload => registerInteraction('note', noteDialog, payload)"
      />
    </div>
  </div>
</template>
