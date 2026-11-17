<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useRedeProjectsStore } from 'dashboard/stores/rede/projects';
import { useAccount } from 'dashboard/composables/useAccount';
import { useRouter } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
});

const { t } = useI18n();
const { isAdmin } = useAdmin();
const projectsStore = useRedeProjectsStore();
const router = useRouter();
const { accountScopedRoute } = useAccount();

const isLoading = computed(() => projectsStore.uiFlags.fetchingList);
const hasProjects = computed(() => projectsStore.records.length > 0);

// Projeto nasce junto com o time, na tela de times das configurações.
const createProject = () =>
  router.push(accountScopedRoute('settings_teams_new'));

onMounted(() => {
  // A casca só precisa saber se a conta tem projetos; a falha cai no estado vazio.
  projectsStore.get().catch(() => {});
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <div class="flex flex-col w-full max-w-[60rem] gap-6 mx-auto px-6 py-8">
      <header class="flex flex-col gap-1">
        <h1 class="text-heading-1 text-n-slate-12">{{ title }}</h1>
        <p v-if="description" class="mb-0 text-body-main text-n-slate-11">
          {{ description }}
        </p>
      </header>

      <div
        v-if="!isLoading && !hasProjects"
        class="flex flex-col items-center gap-3 px-6 py-16 text-center border border-dashed rounded-xl border-n-weak"
      >
        <span class="i-lucide-contact-round size-8 text-n-slate-10" />
        <h2 class="mb-0 text-heading-2 text-n-slate-12">
          {{ t('REDE.CRM.NO_PROJECTS.TITLE') }}
        </h2>
        <p class="mb-0 text-body-main text-n-slate-11">
          {{
            isAdmin
              ? t('REDE.CRM.NO_PROJECTS.DESCRIPTION')
              : t('REDE.CRM.NO_PROJECTS.ASK_ADMIN')
          }}
        </p>
        <Button
          v-if="isAdmin"
          :label="t('REDE.CRM.NO_PROJECTS.CREATE')"
          size="sm"
          @click="createProject"
        />
      </div>

      <slot v-else-if="hasProjects">
        <p class="mb-0 text-body-main text-n-slate-11">
          {{ t('REDE.CRM.COMING_SOON') }}
        </p>
      </slot>
    </div>
  </section>
</template>
