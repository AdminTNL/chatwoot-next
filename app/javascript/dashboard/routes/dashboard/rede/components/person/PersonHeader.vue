<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  contact: { type: Object, required: true },
  canRegister: { type: Boolean, default: true },
});

const emit = defineEmits(['call', 'note']);

const { t } = useI18n();

const details = computed(() =>
  [props.contact.phoneNumber, props.contact.email, props.contact.city].filter(
    Boolean
  )
);
</script>

<template>
  <header
    class="flex flex-wrap items-start justify-between gap-4"
    data-test="person-header"
  >
    <div class="flex flex-col gap-1 min-w-0">
      <h1 class="mb-0 text-heading-1 text-n-slate-12" data-test="person-name">
        {{ contact.name || contact.phoneNumber }}
      </h1>
      <p
        v-if="details.length"
        class="flex flex-wrap mb-0 gap-x-3 text-body-main text-n-slate-11"
        data-test="person-details"
      >
        <span v-for="item in details" :key="item">{{ item }}</span>
      </p>
      <router-link
        :to="{ name: 'contacts_edit', params: { contactId: contact.id } }"
        class="text-sm text-n-brand hover:underline"
        data-test="view-contact"
      >
        {{ t('REDE.PERSON.HEADER.VIEW_CONTACT') }}
      </router-link>
    </div>
    <div v-if="canRegister" class="flex gap-2">
      <Button
        data-test="register-call"
        type="button"
        icon="i-lucide-phone"
        :label="t('REDE.PERSON.HEADER.REGISTER_CALL')"
        @click="emit('call')"
      />
      <Button
        data-test="add-note"
        type="button"
        variant="faded"
        color="slate"
        icon="i-lucide-sticky-note"
        :label="t('REDE.PERSON.HEADER.ADD_NOTE')"
        @click="emit('note')"
      />
    </div>
  </header>
</template>
