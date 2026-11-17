<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import PeopleAPI from 'dashboard/api/rede/people';
import RolesAPI from 'dashboard/api/rede/roles';
import { useRedePersonStore } from 'dashboard/stores/rede/person';
import { useRedeProjectsStore } from 'dashboard/stores/rede/projects';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CallDialog from '../components/person/CallDialog.vue';
import NoteDialog from '../components/person/NoteDialog.vue';
import ParticipationCard from '../components/person/ParticipationCard.vue';
import PersonHeader from '../components/person/PersonHeader.vue';
import Timeline from '../components/person/Timeline.vue';
import TimelineFilters from '../components/person/TimelineFilters.vue';
import { buildTimelineParams } from '../components/person/timelineFilters';

const route = useRoute();
const { t } = useI18n();
const store = useRedePersonStore();
const projectsStore = useRedeProjectsStore();
const currentUser = useMapGetter('getCurrentUser');

const contactId = computed(() => Number(route.params.contactId));
const accountId = computed(() => Number(route.params.accountId));
const currentUserId = computed(() => currentUser.value?.id ?? null);

const roles = ref([]);
const responsibles = ref([]);
const filters = ref({});
const callDialog = ref(null);
const noteDialog = ref(null);
const dialogError = ref('');
const loadFailed = ref(false);

const person = computed(() => store.person);
const participations = computed(() => person.value.participations || []);
const isLoading = computed(
  () => store.uiFlags.fetchingItem && !person.value.contact
);
const isSaving = computed(() => store.uiFlags.savingAction);

// Frentes ativas por projeto, do cadastro (traz has_temperature).
const projectFronts = projectId =>
  projectsStore.records.find(project => project.id === projectId)?.fronts || [];
const activeFronts = projectId =>
  projectFronts(projectId).filter(front => front.status !== 'closed');

// Ligação e nota só em projeto com participação ativa.
const registrableProjects = computed(() =>
  participations.value
    .filter(item => item.status !== 'closed')
    .map(item => item.project)
);
const frontsByProject = computed(() =>
  Object.fromEntries(
    registrableProjects.value.map(project => [
      project.id,
      activeFronts(project.id),
    ])
  )
);
const filterProjects = computed(() =>
  participations.value.map(item => item.project)
);

const showError = error =>
  useAlert(error?.message || t('REDE.PERSON.GENERIC_ERROR'));

// Ação de ficha: a store recarrega ficha e histórico; falha vira alerta.
const perform = async action => {
  try {
    await action();
    return true;
  } catch (error) {
    showError(error);
    return false;
  }
};

const timelineParams = computed(() => buildTimelineParams(filters.value));

const loadTimeline = () =>
  perform(() => store.getTimeline(contactId.value, timelineParams.value));

const applyFilters = value => {
  filters.value = value;
  loadTimeline();
};

const load = async () => {
  store.reset();
  filters.value = {};
  loadFailed.value = false;
  try {
    await store.show(contactId.value);
  } catch (error) {
    loadFailed.value = true;
    showError(error);
    return;
  }
  if (store.notFound) return;
  loadTimeline();
};

const loadLookups = async () => {
  // Papéis e responsáveis só alimentam seletores: falha não trava a ficha.
  const [rolesResult, filtersResult] = await Promise.allSettled([
    RolesAPI.get(),
    PeopleAPI.filters(),
    projectsStore.get(),
  ]);
  if (rolesResult.status === 'fulfilled') {
    roles.value = rolesResult.value.data || [];
  }
  if (filtersResult.status === 'fulfilled') {
    responsibles.value = filtersResult.value.data?.responsibles || [];
  }
};

watch(contactId, load);

onMounted(() => {
  load();
  loadLookups();
});

const withContact = attrs => ({ ...attrs, contactId: contactId.value });

const updateParticipation = (participation, patch) =>
  perform(() =>
    store.updateParticipation(withContact({ id: participation.id, ...patch }))
  );

const setTemperature = (participation, payload) =>
  perform(() =>
    store.setTemperature(
      withContact({ projectId: participation.project.id, ...payload })
    )
  );

const updateAssignment = (participation, payload) =>
  perform(() =>
    store.updateAssignment(
      withContact({ participationId: participation.id, ...payload })
    )
  );

const closeAssignment = (participation, id) =>
  perform(() =>
    store.closeAssignment(
      withContact({ participationId: participation.id, id })
    )
  );

const createAssignment = (participation, payload) =>
  perform(() =>
    store.createAssignment(
      withContact({ participationId: participation.id, ...payload })
    )
  );

const submitDialog = async (dialog, request) => {
  dialogError.value = '';
  try {
    await request();
    dialog.value?.close();
  } catch (error) {
    dialogError.value = error?.message || t('REDE.PERSON.GENERIC_ERROR');
  }
};

const openCall = () => {
  dialogError.value = '';
  callDialog.value?.open();
};
const openNote = () => {
  dialogError.value = '';
  noteDialog.value?.open();
};

const submitCall = payload =>
  submitDialog(callDialog, () => store.logCall(withContact(payload)));
const submitNote = payload =>
  submitDialog(noteDialog, () => store.addNote(withContact(payload)));

const saveInteraction = ({ interactionId, summary, answered }) =>
  perform(() =>
    store.updateInteraction(
      withContact({ id: interactionId, summary, answered })
    )
  );

const loadMore = () =>
  perform(() => store.loadMoreTimeline(contactId.value, timelineParams.value));
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <div class="flex flex-col w-full max-w-[60rem] gap-6 mx-auto px-6 py-8">
      <router-link
        :to="{ name: 'rede_people' }"
        class="self-start text-sm text-n-brand hover:underline"
        data-test="back-to-people"
      >
        {{ t('REDE.PERSON.BACK') }}
      </router-link>

      <div
        v-if="store.notFound"
        class="flex flex-col items-center gap-3 px-6 py-16 text-center border border-dashed rounded-xl border-n-weak"
        data-test="person-not-found"
      >
        <span class="i-lucide-user-round-x size-8 text-n-slate-10" />
        <h2 class="mb-0 text-heading-2 text-n-slate-12">
          {{ t('REDE.PERSON.NOT_FOUND.TITLE') }}
        </h2>
        <router-link
          :to="{ name: 'rede_people' }"
          class="text-sm text-n-brand hover:underline"
        >
          {{ t('REDE.PERSON.NOT_FOUND.BACK') }}
        </router-link>
      </div>

      <div
        v-else-if="loadFailed"
        class="flex flex-col items-center gap-3 px-6 py-16 text-center"
        role="alert"
        data-test="person-load-error"
      >
        <p class="mb-0 text-sm text-n-slate-11">
          {{ t('REDE.PERSON.GENERIC_ERROR') }}
        </p>
        <button
          type="button"
          class="text-sm text-n-brand hover:underline"
          @click="load"
        >
          {{ t('REDE.PERSON.RETRY') }}
        </button>
      </div>

      <div v-else-if="isLoading" class="flex justify-center py-16">
        <Spinner />
      </div>

      <template v-else-if="person.contact">
        <PersonHeader
          :contact="person.contact"
          :can-register="registrableProjects.length > 0"
          @call="openCall"
          @note="openNote"
        />

        <div class="flex flex-col gap-4">
          <ParticipationCard
            v-for="participation in participations"
            :key="participation.id"
            :participation="participation"
            :fronts="projectFronts(participation.project.id)"
            :roles="roles"
            :responsibles="responsibles"
            :is-saving="isSaving"
            @update-participation="
              patch => updateParticipation(participation, patch)
            "
            @set-temperature="payload => setTemperature(participation, payload)"
            @update-assignment="
              payload => updateAssignment(participation, payload)
            "
            @close-assignment="id => closeAssignment(participation, id)"
            @create-assignment="
              payload => createAssignment(participation, payload)
            "
          />
        </div>

        <section class="flex flex-col gap-4">
          <h2 class="mb-0 text-heading-2 text-n-slate-12">
            {{ t('REDE.PERSON.TIMELINE.TITLE') }}
          </h2>
          <TimelineFilters
            :model-value="filters"
            :projects="filterProjects"
            @update:model-value="applyFilters"
          />
          <Timeline
            :events="store.timeline"
            :has-more="Boolean(store.timelineMeta.nextCursor)"
            :is-loading="store.uiFlags.fetchingTimeline"
            :is-saving="isSaving"
            :current-user-id="currentUserId"
            :account-id="accountId"
            @load-more="loadMore"
            @save="saveInteraction"
          />
        </section>
      </template>
    </div>

    <CallDialog
      ref="callDialog"
      :projects="registrableProjects"
      :fronts-by-project="frontsByProject"
      :author-name="currentUser?.name || ''"
      :is-loading="isSaving"
      :error-message="dialogError"
      @submit="submitCall"
    />
    <NoteDialog
      ref="noteDialog"
      :projects="registrableProjects"
      :fronts-by-project="frontsByProject"
      :is-loading="isSaving"
      :error-message="dialogError"
      @submit="submitNote"
    />
  </section>
</template>
