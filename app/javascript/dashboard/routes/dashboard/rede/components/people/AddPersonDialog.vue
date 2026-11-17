<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import ParticipationsAPI from 'dashboard/api/rede/participations';
import FrontsAPI from 'dashboard/api/rede/fronts';
import ContactAPI from 'dashboard/api/contacts';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const props = defineProps({
  // Projetos de GET people/filters (já limitados ao escopo de quem usa).
  projects: { type: Array, default: () => [] },
  roles: { type: Array, default: () => [] },
  responsibles: { type: Array, default: () => [] },
});

const emit = defineEmits(['saved']);

const { t } = useI18n();

const SEARCH_DEBOUNCE_MS = 300;
const MIN_SEARCH_LENGTH = 2;

const dialogRef = ref(null);
const mode = ref('existing');
const contactQuery = ref('');
const contactResults = ref([]);
const searched = ref(false);
const selectedContact = ref(null);
const name = ref('');
const phone = ref('');
const city = ref('');
const projectId = ref('');
const fronts = ref([]);
const frontId = ref('');
const roleId = ref('');
const responsibleId = ref('');
const nextStep = ref('');
const errors = ref({});
const apiError = ref('');
const isSaving = ref(false);

const activeProjects = computed(() =>
  props.projects.filter(project => project.status !== 'closed')
);

const projectOptions = computed(() =>
  activeProjects.value.map(project => ({
    value: project.id,
    label: project.name,
  }))
);
const frontOptions = computed(() => [
  { value: '', label: t('REDE.PEOPLE.ADD.FRONT_NONE') },
  ...fronts.value.map(front => ({ value: front.id, label: front.name })),
]);
const roleOptions = computed(() => [
  { value: '', label: t('REDE.PEOPLE.ADD.ROLE_NONE') },
  ...props.roles.map(role => ({ value: role.id, label: role.name })),
]);
const responsibleOptions = computed(() => [
  { value: '', label: t('REDE.PEOPLE.ADD.RESPONSIBLE_NONE') },
  ...props.responsibles.map(user => ({ value: user.id, label: user.name })),
]);

const reset = () => {
  mode.value = 'existing';
  contactQuery.value = '';
  contactResults.value = [];
  searched.value = false;
  selectedContact.value = null;
  name.value = '';
  phone.value = '';
  city.value = '';
  projectId.value = '';
  fronts.value = [];
  frontId.value = '';
  roleId.value = '';
  responsibleId.value = '';
  nextStep.value = '';
  errors.value = {};
  apiError.value = '';
  isSaving.value = false;
};

const open = () => {
  reset();
  dialogRef.value?.open();
};
const close = () => dialogRef.value?.close();

// Só frentes ativas do projeto escolhido; recarrega a cada troca de projeto.
const loadFronts = async id => {
  frontId.value = '';
  fronts.value = [];
  if (!id) return;
  let list;
  try {
    const { data } = await FrontsAPI.get(id);
    list = data;
  } catch {
    list = props.projects.find(project => project.id === id)?.fronts || [];
  }
  // Ignora a resposta de um projeto que já foi trocado.
  if (projectId.value !== id) return;
  fronts.value = (list || []).filter(front => front.status !== 'closed');
};
watch(projectId, id => loadFronts(id));

const searchContacts = useDebounceFn(async query => {
  if (query.trim().length < MIN_SEARCH_LENGTH) {
    contactResults.value = [];
    searched.value = false;
    return;
  }
  try {
    const { data } = await ContactAPI.search(query.trim());
    contactResults.value = data?.payload || [];
  } catch {
    contactResults.value = [];
  }
  searched.value = true;
}, SEARCH_DEBOUNCE_MS);

const onContactQuery = value => {
  contactQuery.value = value;
  searchContacts(value);
};

const selectContact = contact => {
  selectedContact.value = contact;
  errors.value = { ...errors.value, contact: undefined };
};

const setMode = value => {
  mode.value = value;
  errors.value = {};
  apiError.value = '';
};

const validate = () => {
  const found = {};
  if (!projectId.value) {
    found.project = t('REDE.PEOPLE.ADD.ERRORS.PROJECT_REQUIRED');
  }
  if (mode.value === 'existing' && !selectedContact.value) {
    found.contact = t('REDE.PEOPLE.ADD.ERRORS.CONTACT_REQUIRED');
  }
  if (mode.value === 'new' && !name.value.trim() && !phone.value.trim()) {
    found.person = t('REDE.PEOPLE.ADD.ERRORS.NAME_OR_PHONE_REQUIRED');
  }
  errors.value = found;
  return Object.keys(found).length === 0;
};

const buildPayload = () => {
  const payload = { project_id: Number(projectId.value) };
  if (mode.value === 'existing') {
    payload.contact_id = selectedContact.value.id;
  } else {
    const contact = {};
    if (name.value.trim()) contact.name = name.value.trim();
    if (phone.value.trim()) contact.phone_number = phone.value.trim();
    if (city.value.trim()) contact.city = city.value.trim();
    payload.contact = contact;
  }
  if (frontId.value || roleId.value) {
    const assignment = {};
    if (frontId.value) assignment.front_id = Number(frontId.value);
    if (roleId.value) assignment.role_id = Number(roleId.value);
    payload.assignment = assignment;
  }
  return payload;
};

const errorMessage = error => {
  const data = error?.response?.data;
  return (
    data?.error ||
    data?.message ||
    (Array.isArray(data?.errors) ? data.errors.join(' ') : '') ||
    t('REDE.PEOPLE.ADD.GENERIC_ERROR')
  );
};

// A criação só aceita contato e primeira atuação; responsável e próximo
// passo seguem num PATCH logo depois.
const saveExtras = async participationId => {
  const extras = {};
  if (responsibleId.value) {
    extras.responsible_user_id = Number(responsibleId.value);
  }
  if (nextStep.value.trim()) extras.next_step = nextStep.value.trim();
  if (!Object.keys(extras).length) return true;
  try {
    await ParticipationsAPI.update(participationId, extras);
    return true;
  } catch {
    return false;
  }
};

const submit = async () => {
  apiError.value = '';
  if (!validate()) return;
  isSaving.value = true;
  try {
    const { data } = await ParticipationsAPI.create(buildPayload());
    const extrasSaved = await saveExtras(data.id);
    // A API decide se o telefone já era de um contato (nono dígito): quando
    // devolve outro nome que o digitado, o aviso usa o contato dela.
    const typedName = name.value.trim();
    const matchedContact =
      mode.value === 'new' &&
      typedName &&
      data.contact?.name &&
      data.contact.name !== typedName
        ? data.contact
        : null;
    emit('saved', { participation: data, matchedContact, extrasSaved });
    close();
  } catch (error) {
    apiError.value = errorMessage(error);
  } finally {
    isSaving.value = false;
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    overflow-y-auto
    :title="t('REDE.PEOPLE.ADD.TITLE')"
    :confirm-button-label="t('REDE.PEOPLE.ADD.CONFIRM')"
    :is-loading="isSaving"
    @confirm="submit"
  >
    <div class="flex flex-col gap-4">
      <div class="flex gap-2">
        <button
          v-for="option in ['existing', 'new']"
          :key="option"
          type="button"
          class="px-3 py-1.5 text-sm font-medium rounded-lg"
          :class="
            mode === option
              ? 'bg-n-brand/10 text-n-brand'
              : 'bg-n-alpha-2 text-n-slate-11'
          "
          :data-test="`mode-${option}`"
          :aria-pressed="mode === option"
          @click="setMode(option)"
        >
          {{
            option === 'existing'
              ? t('REDE.PEOPLE.ADD.MODE_EXISTING')
              : t('REDE.PEOPLE.ADD.MODE_NEW')
          }}
        </button>
      </div>

      <template v-if="mode === 'existing'">
        <div class="flex flex-col gap-2">
          <Input
            data-test="contact-search"
            :placeholder="t('REDE.PEOPLE.ADD.SEARCH_PLACEHOLDER')"
            :model-value="contactQuery"
            @update:model-value="onContactQuery"
          />
          <ul
            v-if="contactResults.length"
            class="flex flex-col m-0 overflow-y-auto list-none border rounded-lg max-h-40 border-n-weak"
          >
            <li v-for="contact in contactResults" :key="contact.id">
              <button
                type="button"
                class="flex flex-col w-full px-3 py-2 text-start hover:bg-n-alpha-2"
                :class="{
                  'bg-n-alpha-2': selectedContact?.id === contact.id,
                }"
                :data-test="`contact-result-${contact.id}`"
                @click="selectContact(contact)"
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
            {{ t('REDE.PEOPLE.ADD.NO_RESULTS') }}
          </p>
          <p v-if="errors.contact" class="mb-0 text-sm text-n-ruby-11">
            {{ errors.contact }}
          </p>
        </div>
      </template>

      <template v-else>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <Input
            v-model="name"
            data-test="new-name"
            :label="t('REDE.PEOPLE.ADD.NAME')"
          />
          <Input
            v-model="phone"
            data-test="new-phone"
            type="tel"
            :label="t('REDE.PEOPLE.ADD.PHONE')"
          />
          <Input
            v-model="city"
            data-test="new-city"
            :label="t('REDE.PEOPLE.ADD.CITY')"
          />
        </div>
        <p v-if="errors.person" class="mb-0 -mt-2 text-sm text-n-ruby-11">
          {{ errors.person }}
        </p>
      </template>

      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div class="flex flex-col gap-1">
          <span class="text-heading-3 text-n-slate-12">
            {{ t('REDE.PEOPLE.ADD.PROJECT') }}
          </span>
          <Select
            v-model="projectId"
            data-test="add-project"
            class="!w-full"
            :options="projectOptions"
            :placeholder="t('REDE.PEOPLE.ADD.PROJECT_PLACEHOLDER')"
            :error="errors.project"
          />
          <p v-if="errors.project" class="mb-0 text-sm text-n-ruby-11">
            {{ errors.project }}
          </p>
        </div>
        <div v-if="fronts.length" class="flex flex-col gap-1">
          <span class="text-heading-3 text-n-slate-12">
            {{ t('REDE.PEOPLE.ADD.FRONT') }}
          </span>
          <Select
            v-model="frontId"
            data-test="add-front"
            class="!w-full"
            :options="frontOptions"
          />
        </div>
        <div class="flex flex-col gap-1">
          <span class="text-heading-3 text-n-slate-12">
            {{ t('REDE.PEOPLE.ADD.ROLE') }}
          </span>
          <Select
            v-model="roleId"
            data-test="add-role"
            class="!w-full"
            :options="roleOptions"
          />
        </div>
        <div class="flex flex-col gap-1">
          <span class="text-heading-3 text-n-slate-12">
            {{ t('REDE.PEOPLE.ADD.RESPONSIBLE') }}
          </span>
          <Select
            v-model="responsibleId"
            data-test="add-responsible"
            class="!w-full"
            :options="responsibleOptions"
          />
        </div>
      </div>

      <Input
        v-model="nextStep"
        data-test="add-next-step"
        :label="t('REDE.PEOPLE.ADD.NEXT_STEP')"
      />

      <p v-if="apiError" class="mb-0 text-sm text-n-ruby-11" role="alert">
        {{ apiError }}
      </p>
    </div>
  </Dialog>
</template>
