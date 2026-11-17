<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import ContactAPI from 'dashboard/api/contacts';
import Input from 'dashboard/components-next/input/Input.vue';

// Busca de contato com lista de resultados. Com allowText, o texto digitado
// também pode ser usado como está (indicado por em texto livre).
const props = defineProps({
  placeholder: { type: String, default: '' },
  allowText: { type: Boolean, default: false },
  excludeId: { type: Number, default: null },
});

const emit = defineEmits(['select', 'text']);

const { t } = useI18n();

const SEARCH_DEBOUNCE_MS = 300;
const MIN_SEARCH_LENGTH = 2;

const query = ref('');
const results = ref([]);
const searched = ref(false);

const search = useDebounceFn(async value => {
  if (value.trim().length < MIN_SEARCH_LENGTH) {
    results.value = [];
    searched.value = false;
    return;
  }
  try {
    const { data } = await ContactAPI.search(value.trim());
    results.value = (data?.payload || []).filter(
      contact => contact.id !== props.excludeId
    );
  } catch {
    results.value = [];
  }
  searched.value = true;
}, SEARCH_DEBOUNCE_MS);

const onInput = value => {
  query.value = value;
  search(value);
};

const reset = () => {
  query.value = '';
  results.value = [];
  searched.value = false;
};

const select = contact => {
  emit('select', { id: contact.id, name: contact.name });
  reset();
};

const useText = () => {
  const text = query.value.trim();
  if (!text) return;
  emit('text', text);
  reset();
};
</script>

<template>
  <div class="flex flex-col gap-1.5">
    <Input
      data-test="contact-search"
      size="sm"
      :placeholder="placeholder"
      :model-value="query"
      @update:model-value="onInput"
    />
    <ul
      v-if="results.length"
      class="flex flex-col m-0 overflow-y-auto list-none border rounded-lg max-h-40 border-n-weak"
    >
      <li v-for="contact in results" :key="contact.id">
        <button
          type="button"
          class="flex flex-col w-full px-3 py-1.5 text-start hover:bg-n-alpha-2"
          :data-test="`contact-result-${contact.id}`"
          @click="select(contact)"
        >
          <span class="text-sm font-medium text-n-slate-12">
            {{ contact.name || contact.phone_number }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ contact.phone_number || contact.email }}
          </span>
        </button>
      </li>
    </ul>
    <p v-else-if="searched" class="mb-0 text-sm text-n-slate-11">
      {{ t('REDE.PERSON.CONTACT_SEARCH.NO_RESULTS') }}
    </p>
    <button
      v-if="allowText && query.trim()"
      type="button"
      class="self-start text-sm text-n-brand hover:underline"
      data-test="use-text"
      @click="useText"
    >
      {{ t('REDE.PERSON.CONTACT_SEARCH.USE_TEXT', { text: query.trim() }) }}
    </button>
  </div>
</template>
