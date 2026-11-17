<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

// Etiqueta do projeto na cor dele. Projeto encerrado fica esmaecido.
const props = defineProps({
  project: { type: Object, required: true },
});

const { t } = useI18n();

const isClosed = computed(() => props.project.status === 'closed');
const color = computed(() =>
  /^#[0-9a-f]{6}$/i.test(props.project.color || '')
    ? props.project.color
    : '#64748b'
);

// A cor vem do cadastro do projeto, por isso precisa de estilo em linha:
// fundo translúcido da cor, com um ponto sólido e o texto no tom padrão.
const style = computed(() => ({ backgroundColor: `${color.value}26` }));
const dotStyle = computed(() => ({ backgroundColor: color.value }));
</script>

<template>
  <span
    class="inline-flex items-center gap-1.5 px-2 py-0.5 text-xs font-medium rounded-md whitespace-nowrap text-n-slate-12"
    :class="{ 'opacity-50': isClosed }"
    :style="style"
    :title="isClosed ? t('REDE.PEOPLE.PROJECT_CLOSED') : undefined"
  >
    <span class="size-2 rounded-full shrink-0" :style="dotStyle" />
    {{ project.name }}
  </span>
</template>
