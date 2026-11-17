<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import ContactAPI from 'dashboard/api/contacts';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const emit = defineEmits(['saved']);

const { t } = useI18n();

const dialogRef = ref(null);
const item = ref(null);
const value = ref('');
const saving = ref(false);
const errorMessage = ref('');
const phoneTaken = ref(false);

const FIELD_KEYS = {
  missing_city: 'CITY',
  missing_phone: 'PHONE',
  missing_name: 'NAME',
};

const fieldKey = computed(() => FIELD_KEYS[item.value?.kind] || 'CITY');
const label = computed(() => t(`REDE.QUALITY.COMPLETE.${fieldKey.value}`));

const open = selectedItem => {
  item.value = selectedItem;
  value.value = '';
  errorMessage.value = '';
  phoneTaken.value = false;
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

// A API de contatos substitui additional_attributes inteiro:
// lê o contato antes e devolve os atributos que já existem.
const buildPayload = async trimmed => {
  const { kind, contact } = item.value;
  if (kind === 'missing_phone') return { phone_number: trimmed };
  if (kind === 'missing_name') return { name: trimmed };
  const { data } = await ContactAPI.show(contact.id);
  const current = data?.payload?.additional_attributes || {};
  return { additional_attributes: { ...current, city: trimmed } };
};

const submit = async () => {
  const trimmed = value.value.trim();
  errorMessage.value = '';
  phoneTaken.value = false;
  if (!trimmed) {
    errorMessage.value = t('REDE.QUALITY.COMPLETE.REQUIRED');
    return;
  }
  // A API de contatos ignora em silêncio um telefone fora do formato E.164.
  const isPhone = item.value.kind === 'missing_phone';
  if (isPhone && !/^\+[1-9]\d{1,14}$/.test(trimmed)) {
    errorMessage.value = t('REDE.QUALITY.COMPLETE.PHONE_INVALID');
    return;
  }
  saving.value = true;
  try {
    const payload = await buildPayload(trimmed);
    await ContactAPI.update(item.value.contact.id, payload);
    emit('saved', item.value);
    close();
  } catch (error) {
    const status = error?.response?.status;
    if (status === 422 && item.value.kind === 'missing_phone') {
      phoneTaken.value = true;
    } else {
      errorMessage.value =
        error?.response?.data?.message || t('REDE.QUALITY.COMPLETE.ERROR');
    }
  } finally {
    saving.value = false;
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('REDE.QUALITY.COMPLETE.TITLE', { field: label })"
    :confirm-button-label="t('REDE.QUALITY.COMPLETE.SAVE')"
    :is-loading="saving"
    @confirm="submit"
  >
    <div class="flex flex-col gap-3">
      <p class="mb-0 text-body-main text-n-slate-11">
        {{ item?.contact?.name }}
      </p>
      <Input
        v-model="value"
        :label="label"
        :message="errorMessage"
        :message-type="errorMessage ? 'error' : 'info'"
      />
      <div
        v-if="phoneTaken"
        data-test="phone-taken"
        class="flex flex-col gap-1"
      >
        <p class="mb-0 text-body-main text-n-ruby-11">
          {{ t('REDE.QUALITY.COMPLETE.PHONE_TAKEN') }}
        </p>
        <p class="mb-0 text-body-main text-n-slate-11">
          {{ t('REDE.QUALITY.COMPLETE.PHONE_TAKEN_HINT') }}
        </p>
      </div>
    </div>
  </Dialog>
</template>
