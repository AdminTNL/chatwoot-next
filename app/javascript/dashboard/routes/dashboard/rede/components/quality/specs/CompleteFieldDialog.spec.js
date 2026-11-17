import { mount, flushPromises } from '@vue/test-utils';
import ContactAPI from 'dashboard/api/contacts';
import CompleteFieldDialog from '../CompleteFieldDialog.vue';

vi.mock('dashboard/api/contacts', () => ({
  default: { show: vi.fn(), update: vi.fn() },
}));

const DialogStub = {
  name: 'Dialog',
  props: ['isLoading'],
  emits: ['confirm'],
  template:
    '<div><slot /><button data-test="confirm" @click="$emit(\'confirm\')" /></div>',
  methods: { open() {}, close() {} },
};

const contact = { id: 7, name: 'Diego', phoneNumber: null, city: null };

const build = async kind => {
  const wrapper = mount(CompleteFieldDialog, {
    global: { stubs: { Dialog: DialogStub } },
  });
  wrapper.vm.open({ kind, contact });
  await wrapper.vm.$nextTick();
  return wrapper;
};

const fill = async (wrapper, value) => {
  await wrapper.find('input').setValue(value);
  await wrapper.find('[data-test="confirm"]').trigger('click');
  await flushPromises();
};

describe('CompleteFieldDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    ContactAPI.show.mockResolvedValue({
      data: {
        payload: {
          id: 7,
          additional_attributes: { country: 'BR', city: '' },
        },
      },
    });
    ContactAPI.update.mockResolvedValue({ data: {} });
  });

  it('saves the city inside additional_attributes keeping the others', async () => {
    const wrapper = await build('missing_city');
    await fill(wrapper, 'Recife');
    expect(ContactAPI.update).toHaveBeenCalledWith(7, {
      additional_attributes: { country: 'BR', city: 'Recife' },
    });
    expect(wrapper.emitted('saved')).toHaveLength(1);
  });

  it('saves the phone as a native field', async () => {
    const wrapper = await build('missing_phone');
    await fill(wrapper, '+5581999990000');
    expect(ContactAPI.update).toHaveBeenCalledWith(7, {
      phone_number: '+5581999990000',
    });
    expect(wrapper.emitted('saved')).toHaveLength(1);
  });

  it('saves the name as a native field', async () => {
    const wrapper = await build('missing_name');
    await fill(wrapper, 'Diego Lima');
    expect(ContactAPI.update).toHaveBeenCalledWith(7, { name: 'Diego Lima' });
  });

  it('does not save an empty value', async () => {
    const wrapper = await build('missing_city');
    await fill(wrapper, '   ');
    expect(ContactAPI.update).not.toHaveBeenCalled();
    expect(wrapper.emitted('saved')).toBeUndefined();
  });

  it('rejects a phone outside the international format without calling the API', async () => {
    const wrapper = await build('missing_phone');
    await fill(wrapper, '81 99999-0000');
    expect(ContactAPI.update).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('international format');
  });

  it('explains a phone already used by someone else', async () => {
    ContactAPI.update.mockRejectedValue({
      response: {
        status: 422,
        data: { message: 'Phone number has already been taken' },
      },
    });
    const wrapper = await build('missing_phone');
    await fill(wrapper, '+5581999990000');
    expect(wrapper.find('[data-test="phone-taken"]').text()).toContain(
      'That phone number already belongs to someone else.'
    );
    expect(wrapper.emitted('saved')).toBeUndefined();
  });
});
