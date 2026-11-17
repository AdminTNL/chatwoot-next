<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { useRedeApiTokensStore } from 'dashboard/stores/rede/apiTokens';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const { t, locale } = useI18n();
const store = useStore();
const tokensStore = useRedeApiTokensStore();

const getAgentById = useMapGetter('agents/getAgentById');

const createDialogRef = ref(null);
const revokeDialogRef = ref(null);
const newName = ref('');
const nameTouched = ref(false);
const selectedToken = ref({});

const tokens = computed(() => tokensStore.records);
const isLoading = computed(() => tokensStore.uiFlags.fetchingList);
// O valor em claro só existe enquanto o diálogo de criação está aberto.
const plainToken = computed(() => tokensStore.lastCreatedToken);
const nameError = computed(() =>
  nameTouched.value && !newName.value.trim()
    ? t('REDE.API_TOKENS.NAME_REQUIRED')
    : ''
);

onMounted(() => {
  store.dispatch('agents/get');
  tokensStore.get().catch(() => {
    useAlert(t('REDE.API_TOKENS.LOAD_ERROR'));
  });
});

onBeforeUnmount(() => tokensStore.clearLastCreated());

const createdByName = token =>
  getAgentById.value(token.createdByUserId)?.name || '-';

const formatDate = value =>
  value ? new Date(value).toLocaleString(locale.value) : '-';

const openCreate = () => {
  tokensStore.clearLastCreated();
  newName.value = '';
  nameTouched.value = false;
  createDialogRef.value?.open();
};

const handleCreateConfirm = async () => {
  if (plainToken.value) {
    createDialogRef.value?.close();
    return;
  }
  nameTouched.value = true;
  if (!newName.value.trim()) return;
  try {
    await tokensStore.create({ name: newName.value.trim() });
    // O create não devolve criador nem último uso; recarrega a lista. O valor em claro segue só em lastCreatedToken.
    await tokensStore.get();
  } catch (error) {
    useAlert(error?.message || t('REDE.API_TOKENS.CREATE_ERROR'));
  }
};

const handleCreateClose = () => {
  tokensStore.clearLastCreated();
  newName.value = '';
};

const copyToken = async () => {
  try {
    await copyTextToClipboard(plainToken.value);
    useAlert(t('REDE.COPY.SUCCESS'));
  } catch {
    useAlert(t('REDE.COPY.ERROR'));
  }
};

const openRevoke = token => {
  selectedToken.value = token;
  revokeDialogRef.value?.open();
};

const confirmRevoke = async () => {
  try {
    await tokensStore.revoke(selectedToken.value.id);
    useAlert(t('REDE.API_TOKENS.REVOKE.SUCCESS'));
  } catch (error) {
    useAlert(error?.message || t('REDE.API_TOKENS.REVOKE.ERROR'));
  }
  revokeDialogRef.value?.close();
};
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="t('REDE.API_TOKENS.LOADING')"
    :no-records-found="!tokens.length"
    :no-records-message="t('REDE.API_TOKENS.EMPTY')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('REDE.API_TOKENS.HEADER')"
        :description="t('REDE.API_TOKENS.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="t('REDE.API_TOKENS.CREATE')"
            size="sm"
            @click="openCreate"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <div class="divide-y divide-n-weak border-t border-n-weak">
        <div
          v-for="token in tokens"
          :key="token.id"
          class="flex justify-between flex-row items-start gap-4 py-4"
        >
          <div class="flex flex-col items-start gap-1">
            <div class="flex items-center gap-2">
              <span class="text-heading-3 text-n-slate-12">
                {{ token.name }}
              </span>
              <span
                class="px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-11"
              >
                {{
                  token.revokedAt
                    ? t('REDE.API_TOKENS.STATUS.REVOKED')
                    : t('REDE.API_TOKENS.STATUS.ACTIVE')
                }}
              </span>
            </div>
            <p class="mb-0 text-body-main text-n-slate-11">
              {{ t('REDE.API_TOKENS.PREFIX') }}:
              <code>{{ token.tokenPrefix }}</code>
              ·
              {{ t('REDE.API_TOKENS.CREATED_BY') }}: {{ createdByName(token) }}
              ·
              {{ t('REDE.API_TOKENS.LAST_USED') }}:
              {{
                token.lastUsedAt
                  ? formatDate(token.lastUsedAt)
                  : t('REDE.API_TOKENS.NEVER_USED')
              }}
            </p>
          </div>
          <Button
            v-if="!token.revokedAt"
            :label="t('REDE.API_TOKENS.REVOKE.BUTTON')"
            variant="faded"
            color="ruby"
            size="sm"
            @click="openRevoke(token)"
          />
        </div>
      </div>
    </template>

    <Dialog
      ref="createDialogRef"
      :title="t('REDE.API_TOKENS.DIALOG.TITLE')"
      :description="plainToken ? '' : t('REDE.API_TOKENS.DIALOG.DESCRIPTION')"
      :confirm-button-label="
        plainToken
          ? t('REDE.API_TOKENS.DIALOG.DONE')
          : t('REDE.API_TOKENS.DIALOG.CREATE')
      "
      :show-cancel-button="!plainToken"
      :is-loading="tokensStore.uiFlags.creatingItem"
      @confirm="handleCreateConfirm"
      @close="handleCreateClose"
    >
      <div v-if="plainToken" class="flex flex-col gap-3">
        <p class="mb-0 text-sm font-medium text-n-ruby-11">
          {{ t('REDE.API_TOKENS.DIALOG.WARNING') }}
        </p>
        <div class="flex items-center gap-2">
          <code
            class="flex-1 px-2 py-2 text-sm break-all rounded-md bg-n-alpha-2 text-n-slate-12"
          >
            {{ plainToken }}
          </code>
          <Button
            type="button"
            variant="faded"
            color="slate"
            size="sm"
            icon="i-lucide-copy"
            :label="t('REDE.COPY.BUTTON')"
            @click="copyToken"
          />
        </div>
      </div>
      <Input
        v-else
        v-model="newName"
        :label="t('REDE.API_TOKENS.DIALOG.NAME_LABEL')"
        :placeholder="t('REDE.API_TOKENS.DIALOG.NAME_PLACEHOLDER')"
        :message="nameError"
        :message-type="nameError ? 'error' : 'info'"
      />
    </Dialog>

    <Dialog
      ref="revokeDialogRef"
      type="alert"
      :title="t('REDE.API_TOKENS.REVOKE.TITLE', { name: selectedToken.name })"
      :description="t('REDE.API_TOKENS.REVOKE.MESSAGE')"
      :confirm-button-label="t('REDE.API_TOKENS.REVOKE.BUTTON')"
      @confirm="confirmRevoke"
    />
  </SettingsLayout>
</template>
