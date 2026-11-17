<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useRedeProjectsStore } from 'dashboard/stores/rede/projects';
import { useRedeQualityStore } from 'dashboard/stores/rede/quality';
import Select from 'dashboard/components-next/select/Select.vue';
import CrmPageShell from '../components/CrmPageShell.vue';
import QualityStats from '../components/quality/QualityStats.vue';
import DuplicatePair from '../components/quality/DuplicatePair.vue';
import IncompleteItem from '../components/quality/IncompleteItem.vue';
import MergeDialog from '../components/quality/MergeDialog.vue';
import CompleteFieldDialog from '../components/quality/CompleteFieldDialog.vue';

const { t } = useI18n();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const projectsStore = useRedeProjectsStore();
const qualityStore = useRedeQualityStore();

const projectId = ref(null);
const loadError = ref(false);
const mergeDialogRef = ref(null);
const completeDialogRef = ref(null);

// Duplicado só existe dentro de um projeto: a tela sempre tem um escolhido.
const activeProjects = computed(() =>
  projectsStore.records.filter(project => project.status === 'active')
);
const projectOptions = computed(() =>
  activeProjects.value.map(project => ({
    value: project.id,
    label: project.name,
  }))
);

const duplicates = computed(() => qualityStore.duplicates);
const incompletes = computed(() => qualityStore.incompletes);
const counts = computed(() => qualityStore.counts);
const uiFlags = computed(() => qualityStore.uiFlags);

const busy = computed(
  () => !!(uiFlags.value.dismissing || uiFlags.value.merging)
);
const isEmpty = computed(
  () =>
    !uiFlags.value.fetchingList &&
    !loadError.value &&
    !duplicates.value.length &&
    !incompletes.value.length
);

const load = async () => {
  if (!projectId.value) return;
  loadError.value = false;
  try {
    await qualityStore.get(projectId.value);
  } catch (error) {
    loadError.value = true;
    useAlert(error?.message || t('REDE.QUALITY.LOAD_ERROR'));
  }
};

const dismiss = async pair => {
  try {
    await qualityStore.dismiss({
      projectId: pair.projectId,
      contactAId: pair.contactA.id,
      contactBId: pair.contactB.id,
    });
    useAlert(t('REDE.QUALITY.PAIR.DISMISS_SUCCESS'));
  } catch (error) {
    useAlert(error?.message || t('REDE.QUALITY.PAIR.DISMISS_ERROR'));
  }
};

const openMerge = pair => mergeDialogRef.value?.open(pair);

// Se o merge falhar a API faz rollback: o diálogo e o par continuam onde estão.
const merge = async payload => {
  try {
    await qualityStore.merge(payload);
    mergeDialogRef.value?.close();
    useAlert(t('REDE.QUALITY.MERGE.SUCCESS'));
  } catch (error) {
    useAlert(error?.message || t('REDE.QUALITY.MERGE.ERROR'));
  }
};

const openComplete = item => completeDialogRef.value?.open(item);

const openRecord = contactId =>
  router.push(accountScopedRoute('rede_person', { contactId }));

watch(projectId, load);

onMounted(async () => {
  try {
    await projectsStore.get();
  } catch {
    // A casca já cai no estado vazio quando não há projetos.
  }
  if (!projectId.value) projectId.value = activeProjects.value[0]?.id ?? null;
});

onBeforeUnmount(() => qualityStore.reset());
</script>

<template>
  <CrmPageShell
    :title="t('REDE.CRM.QUALITY.TITLE')"
    :description="t('REDE.CRM.QUALITY.DESCRIPTION')"
  >
    <div class="flex flex-col gap-6">
      <div class="flex flex-col gap-1 max-w-xs">
        <span class="text-label text-n-slate-11">
          {{ t('REDE.QUALITY.PROJECT_LABEL') }}
        </span>
        <Select v-model="projectId" :options="projectOptions" />
      </div>

      <template v-if="projectId">
        <QualityStats :counts="counts" />

        <p
          v-if="loadError"
          class="mb-0 text-body-main text-n-ruby-11"
          data-test="load-error"
        >
          {{ t('REDE.QUALITY.LOAD_ERROR') }}
        </p>

        <p
          v-else-if="isEmpty"
          class="mb-0 text-body-main text-n-slate-11"
          data-test="empty"
        >
          {{ t('REDE.QUALITY.EMPTY') }}
        </p>

        <template v-else>
          <section v-if="duplicates.length" class="flex flex-col gap-3">
            <h2 class="mb-0 text-heading-2 text-n-slate-12">
              {{ t('REDE.QUALITY.DUPLICATES_TITLE') }}
            </h2>
            <DuplicatePair
              v-for="pair in duplicates"
              :key="`${pair.contactA.id}-${pair.contactB.id}`"
              :pair="pair"
              :busy="busy"
              @dismiss="dismiss"
              @merge="openMerge"
            />
          </section>

          <section v-if="incompletes.length" class="flex flex-col gap-3">
            <h2 class="mb-0 text-heading-2 text-n-slate-12">
              {{ t('REDE.QUALITY.INCOMPLETES_TITLE') }}
            </h2>
            <IncompleteItem
              v-for="item in incompletes"
              :key="`${item.kind}-${item.contact.id}`"
              :item="item"
              @complete="openComplete"
              @open-record="openRecord"
            />
          </section>
        </template>
      </template>
    </div>

    <MergeDialog
      ref="mergeDialogRef"
      :is-loading="!!uiFlags.merging"
      @confirm="merge"
    />
    <CompleteFieldDialog ref="completeDialogRef" @saved="load" />
  </CrmPageShell>
</template>
