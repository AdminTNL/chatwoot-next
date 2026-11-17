import { mount, flushPromises } from '@vue/test-utils';
import AddPersonDialog from '../AddPersonDialog.vue';
import ParticipationsAPI from 'dashboard/api/rede/participations';
import FrontsAPI from 'dashboard/api/rede/fronts';
import ContactAPI from 'dashboard/api/contacts';

vi.mock('dashboard/api/rede/participations', () => ({
  default: { create: vi.fn(), update: vi.fn() },
}));
vi.mock('dashboard/api/rede/fronts', () => ({ default: { get: vi.fn() } }));
vi.mock('dashboard/api/contacts', () => ({ default: { search: vi.fn() } }));

const DialogStub = {
  props: ['title', 'isLoading'],
  emits: ['confirm', 'close'],
  template: '<div><slot /></div>',
  methods: { open() {}, close() {} },
};

const projects = [
  { id: 1, name: 'Mobiliza', status: 'active', fronts: [] },
  { id: 2, name: 'PE', status: 'active', fronts: [] },
  { id: 3, name: 'Velho', status: 'closed', fronts: [] },
];
const roles = [{ id: 7, key: 'lead', name: 'Lideranca' }];
const responsibles = [{ id: 5, name: 'Bia' }];

const factory = () =>
  mount(AddPersonDialog, {
    props: { projects, roles, responsibles },
    global: { stubs: { Dialog: DialogStub } },
  });

const confirm = async wrapper => {
  wrapper.findComponent(DialogStub).vm.$emit('confirm');
  await flushPromises();
};
const pick = (wrapper, test, value) =>
  wrapper.find(`[data-test="${test}"] select`).setValue(value);

describe('AddPersonDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    FrontsAPI.get.mockResolvedValue({
      data: [
        { id: 10, name: 'Campo', status: 'active' },
        { id: 11, name: 'Antiga', status: 'closed' },
      ],
    });
    ParticipationsAPI.create.mockResolvedValue({
      data: { id: 99, contact: { id: 3, name: 'Ana', phone_number: '+55' } },
    });
    ParticipationsAPI.update.mockResolvedValue({ data: {} });
  });

  it('requires a project', async () => {
    const wrapper = factory();
    await wrapper.find('[data-test="mode-new"]').trigger('click');
    await wrapper.find('input[data-test="new-name"]').setValue('Ana');
    await confirm(wrapper);
    expect(ParticipationsAPI.create).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('Choose a project.');
  });

  it('lists only active projects', () => {
    const wrapper = factory();
    const labels = wrapper
      .findAll('[data-test="add-project"] option')
      .map(option => option.text());
    expect(labels).toContain('PE');
    expect(labels).not.toContain('Velho');
  });

  it('requires name or phone in new person mode', async () => {
    const wrapper = factory();
    await wrapper.find('[data-test="mode-new"]').trigger('click');
    await pick(wrapper, 'add-project', '1');
    await confirm(wrapper);
    expect(ParticipationsAPI.create).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('Enter a name or a phone number.');
  });

  it('requires a contact in existing mode', async () => {
    const wrapper = factory();
    await pick(wrapper, 'add-project', '1');
    await confirm(wrapper);
    expect(ParticipationsAPI.create).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('Select a contact.');
  });

  it('sends the contact id for an existing contact', async () => {
    vi.useFakeTimers();
    ContactAPI.search.mockResolvedValue({
      data: {
        payload: [{ id: 3, name: 'Ana', phone_number: '+5581999990000' }],
      },
    });
    const wrapper = factory();
    await wrapper.find('input[data-test="contact-search"]').setValue('Ana');
    vi.advanceTimersByTime(300);
    vi.useRealTimers();
    await flushPromises();
    expect(ContactAPI.search).toHaveBeenCalledTimes(1);
    await wrapper.find('[data-test="contact-result-3"]').trigger('click');
    await pick(wrapper, 'add-project', '1');
    await confirm(wrapper);
    expect(ParticipationsAPI.create).toHaveBeenCalledWith({
      project_id: 1,
      contact_id: 3,
    });
  });

  it('sends name, phone and city for a new person with the first assignment', async () => {
    const wrapper = factory();
    await wrapper.find('[data-test="mode-new"]').trigger('click');
    await wrapper.find('input[data-test="new-name"]').setValue('Ana');
    await wrapper
      .find('input[data-test="new-phone"]')
      .setValue('+5581999990000');
    await wrapper.find('input[data-test="new-city"]').setValue('Recife');
    await pick(wrapper, 'add-project', '2');
    await flushPromises();
    await pick(wrapper, 'add-front', '10');
    await pick(wrapper, 'add-role', '7');
    await confirm(wrapper);
    expect(ParticipationsAPI.create).toHaveBeenCalledWith({
      project_id: 2,
      contact: { name: 'Ana', phone_number: '+5581999990000', city: 'Recife' },
      assignment: { front_id: 10, role_id: 7 },
    });
  });

  it('saves responsible and next step with a follow up update', async () => {
    const wrapper = factory();
    await wrapper.find('[data-test="mode-new"]').trigger('click');
    await wrapper.find('input[data-test="new-name"]').setValue('Ana');
    await pick(wrapper, 'add-project', '1');
    await pick(wrapper, 'add-responsible', '5');
    await wrapper.find('input[data-test="add-next-step"]').setValue('Ligar');
    await confirm(wrapper);
    expect(ParticipationsAPI.update).toHaveBeenCalledWith(99, {
      responsible_user_id: 5,
      next_step: 'Ligar',
    });
  });

  it('reloads the active fronts when the project changes', async () => {
    const wrapper = factory();
    await pick(wrapper, 'add-project', '1');
    await flushPromises();
    expect(FrontsAPI.get).toHaveBeenLastCalledWith(1);
    await pick(wrapper, 'add-project', '2');
    await flushPromises();
    expect(FrontsAPI.get).toHaveBeenLastCalledWith(2);
    expect(FrontsAPI.get).toHaveBeenCalledTimes(2);
    const labels = wrapper
      .findAll('[data-test="add-front"] option')
      .map(option => option.text());
    expect(labels).toContain('Campo');
    expect(labels).not.toContain('Antiga');
  });

  it('emits saved with the contact when the API reused another one', async () => {
    ParticipationsAPI.create.mockResolvedValue({
      data: {
        id: 99,
        contact: { id: 3, name: 'Ana Souza', phone_number: '+55' },
      },
    });
    const wrapper = factory();
    await wrapper.find('[data-test="mode-new"]').trigger('click');
    await wrapper.find('input[data-test="new-name"]').setValue('Aninha');
    await pick(wrapper, 'add-project', '1');
    await confirm(wrapper);
    const [payload] = wrapper.emitted('saved')[0];
    expect(payload.matchedContact).toEqual(
      expect.objectContaining({ name: 'Ana Souza' })
    );
  });

  it('shows the API message on a 422', async () => {
    ParticipationsAPI.create.mockRejectedValue({
      response: { status: 422, data: { error: 'Already in this project' } },
    });
    const wrapper = factory();
    await wrapper.find('[data-test="mode-new"]').trigger('click');
    await wrapper.find('input[data-test="new-name"]').setValue('Ana');
    await pick(wrapper, 'add-project', '1');
    await confirm(wrapper);
    expect(wrapper.text()).toContain('Already in this project');
    expect(wrapper.emitted('saved')).toBeUndefined();
  });
});
