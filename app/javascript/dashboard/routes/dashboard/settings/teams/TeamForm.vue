<script setup>
import { reactive, ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import {
  PROJECT_COLOR_PALETTE,
  normalizeHexColor,
  validateProjectForm,
} from './helpers/projectForm';

const props = defineProps({
  onSubmit: { type: Function, default: () => {} },
  submitInProgress: { type: Boolean, default: false },
  formData: { type: Object, default: () => ({}) },
  submitButtonText: { type: String, default: '' },
});

const { t } = useI18n();

const state = reactive({
  name: props.formData.name || '',
  description: props.formData.description || '',
  color: props.formData.color || PROJECT_COLOR_PALETTE[0],
});
const hexInput = ref(state.color);
const submitted = ref(false);

const slug = computed(() => props.formData.slug || '');
const errors = computed(() => validateProjectForm(state));

const nameError = computed(() =>
  submitted.value && errors.value.name
    ? t(`REDE.PROJECT_FORM.NAME.${errors.value.name}`)
    : ''
);
const colorError = computed(() =>
  errors.value.color ? t(`REDE.PROJECT_FORM.COLOR.${errors.value.color}`) : ''
);

const selectColor = color => {
  state.color = color;
  hexInput.value = color;
};

const onHexInput = value => {
  hexInput.value = value;
  state.color = normalizeHexColor(value);
};

const copySlug = async () => {
  try {
    await copyTextToClipboard(slug.value);
    useAlert(t('REDE.COPY.SUCCESS'));
  } catch {
    useAlert(t('REDE.COPY.ERROR'));
  }
};

const handleSubmit = () => {
  submitted.value = true;
  if (Object.keys(errors.value).length) return;
  props.onSubmit({
    name: state.name.trim(),
    color: state.color,
    description: state.description,
  });
};
</script>

<template>
  <div class="flex-shrink-0 w-full">
    <form class="mx-0 grid gap-4" @submit.prevent="handleSubmit">
      <Input
        v-model="state.name"
        :label="t('TEAMS_SETTINGS.FORM.NAME.LABEL')"
        :placeholder="t('TEAMS_SETTINGS.FORM.NAME.PLACEHOLDER')"
        :message="nameError"
        :message-type="nameError ? 'error' : 'info'"
      />

      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('REDE.PROJECT_FORM.COLOR.LABEL') }}
        </span>
        <div class="flex flex-wrap items-center gap-2">
          <button
            v-for="color in PROJECT_COLOR_PALETTE"
            :key="color"
            type="button"
            class="size-6 rounded-full outline outline-2 outline-offset-2"
            :class="
              state.color.toLowerCase() === color.toLowerCase()
                ? 'outline-n-brand'
                : 'outline-transparent'
            "
            :style="{ backgroundColor: color }"
            :aria-label="color"
            @click="selectColor(color)"
          />
        </div>
        <Input
          :model-value="hexInput"
          :label="t('REDE.PROJECT_FORM.COLOR.HEX_LABEL')"
          :placeholder="t('REDE.PROJECT_FORM.COLOR.PLACEHOLDER')"
          :message="colorError"
          :message-type="colorError ? 'error' : 'info'"
          @update:model-value="onHexInput"
        />
      </div>

      <Input
        v-model="state.description"
        :label="t('TEAMS_SETTINGS.FORM.DESCRIPTION.LABEL')"
        :placeholder="t('TEAMS_SETTINGS.FORM.DESCRIPTION.PLACEHOLDER')"
      />

      <div v-if="slug" class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('REDE.PROJECT_FORM.SLUG.LABEL') }}
        </span>
        <div class="flex items-center gap-2">
          <code
            class="px-2 py-1 text-sm rounded-md bg-n-alpha-2 text-n-slate-12"
          >
            {{ slug }}
          </code>
          <NextButton
            type="button"
            variant="ghost"
            color="slate"
            size="sm"
            icon="i-lucide-copy"
            :label="t('REDE.COPY.BUTTON')"
            @click="copySlug"
          />
        </div>
        <p class="mb-0 text-xs text-n-slate-11">
          {{ t('REDE.PROJECT_FORM.SLUG.HELP') }}
        </p>
      </div>

      <div class="flex flex-row justify-end gap-2 py-2 px-0 w-full">
        <div class="w-full">
          <NextButton
            type="submit"
            :label="submitButtonText"
            :disabled="submitInProgress"
            :is-loading="submitInProgress"
          />
        </div>
      </div>
    </form>
  </div>
</template>
