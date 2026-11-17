<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { useRedeProjectsStore } from 'dashboard/stores/rede/projects';

import Button from 'dashboard/components-next/button/Button.vue';
import FrontDialog from './FrontDialog.vue';

defineProps({
  project: { type: Object, required: true },
});

const { t } = useI18n();
const projectsStore = useRedeProjectsStore();
const frontDialogRef = ref(null);

const copyPublicId = async publicId => {
  try {
    await copyTextToClipboard(publicId);
    useAlert(t('REDE.COPY.SUCCESS'));
  } catch {
    useAlert(t('REDE.COPY.ERROR'));
  }
};

const loading = ref({});

const toggleStatus = async (projectId, front) => {
  loading.value[front.id] = true;
  try {
    if (front.status === 'closed') {
      await projectsStore.reopenFront(projectId, front.id);
    } else {
      await projectsStore.closeFront(projectId, front.id);
    }
  } catch (error) {
    useAlert(error?.message || t('REDE.FRONTS.SAVE_ERROR'));
  } finally {
    loading.value[front.id] = false;
  }
};
</script>

<template>
  <section class="flex flex-col gap-4 pt-6 border-t border-n-weak">
    <header class="flex items-start justify-between gap-4">
      <div class="flex flex-col gap-1">
        <h3 class="mb-0 text-heading-3 text-n-slate-12">
          {{ t('REDE.FRONTS.TITLE') }}
        </h3>
        <p class="mb-0 text-body-main text-n-slate-11">
          {{ t('REDE.FRONTS.DESCRIPTION') }}
        </p>
      </div>
      <Button
        type="button"
        size="sm"
        :label="t('REDE.FRONTS.NEW')"
        @click="frontDialogRef.open()"
      />
    </header>

    <p
      v-if="!project.fronts?.length"
      class="mb-0 py-6 text-center text-body-main text-n-slate-11"
    >
      {{ t('REDE.FRONTS.EMPTY') }}
    </p>
    <ul
      v-else
      class="mb-0 list-none divide-y divide-n-weak border-t border-n-weak"
    >
      <li
        v-for="front in project.fronts"
        :key="front.id"
        class="flex items-center justify-between gap-4 py-3"
      >
        <div class="flex flex-col gap-1">
          <div class="flex items-center gap-2">
            <span class="text-heading-3 text-n-slate-12">{{ front.name }}</span>
            <span
              v-if="front.status === 'closed'"
              class="px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-11"
            >
              {{ t('REDE.STATUS.CLOSED') }}
            </span>
          </div>
          <span class="text-body-main text-n-slate-11">
            {{
              front.hasTemperature
                ? t('REDE.FRONTS.WITH_TEMPERATURE')
                : t('REDE.FRONTS.WITHOUT_TEMPERATURE')
            }}
          </span>
          <div class="flex items-center gap-1 text-xs text-n-slate-11">
            <span>{{ t('REDE.FRONTS.PUBLIC_ID') }}</span>
            <code>{{ front.publicId }}</code>
            <Button
              type="button"
              variant="ghost"
              color="slate"
              size="xs"
              icon="i-lucide-copy"
              :label="t('REDE.COPY.BUTTON')"
              @click="copyPublicId(front.publicId)"
            />
          </div>
        </div>
        <div class="flex items-center gap-2">
          <Button
            type="button"
            variant="faded"
            color="slate"
            size="sm"
            :label="t('REDE.FRONTS.EDIT')"
            @click="frontDialogRef.open(front)"
          />
          <Button
            type="button"
            variant="faded"
            color="slate"
            size="sm"
            :label="
              front.status === 'closed'
                ? t('REDE.ACTIONS.REOPEN')
                : t('REDE.ACTIONS.CLOSE')
            "
            :is-loading="loading[front.id]"
            :disabled="loading[front.id]"
            @click="toggleStatus(project.id, front)"
          />
        </div>
      </li>
    </ul>

    <FrontDialog ref="frontDialogRef" :project-id="project.id" />
  </section>
</template>
