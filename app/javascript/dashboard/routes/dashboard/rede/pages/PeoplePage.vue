<script setup>
import { useI18n } from 'vue-i18n';
import CrmPageShell from '../components/CrmPageShell.vue';

const { t } = useI18n();
</script>

<template>
  <CrmPageShell
    :title="t('REDE.CRM.PEOPLE.TITLE')"
    :description="t('REDE.CRM.PEOPLE.DESCRIPTION')"
  />
</template>
