import { mount } from '@vue/test-utils';
import MergeDialog from '../MergeDialog.vue';

const DialogStub = {
  name: 'Dialog',
  props: ['confirmButtonLabel', 'disableConfirmButton', 'isLoading'],
  emits: ['confirm'],
  template:
    '<div><slot /><button data-test="confirm" :disabled="disableConfirmButton" @click="$emit(\'confirm\')" /></div>',
  methods: { open() {}, close() {} },
};

const pair = {
  projectId: 3,
  contactA: { id: 1, name: 'Ana Souza', phoneNumber: '+5581', city: 'Recife' },
  contactB: { id: 2, name: 'Ana S.', phoneNumber: '+5581', city: null },
};

const build = async () => {
  const wrapper = mount(MergeDialog, {
    global: { stubs: { Dialog: DialogStub } },
  });
  wrapper.vm.open(pair);
  await wrapper.vm.$nextTick();
  return wrapper;
};

describe('MergeDialog', () => {
  it('warns that the merge cannot be undone', async () => {
    const wrapper = await build();
    const warning = wrapper.find('[data-test="irreversible-warning"]');
    expect(warning.exists()).toBe(true);
    expect(warning.text()).toContain('cannot be undone');
  });

  it('requires choosing the base before confirming', async () => {
    const wrapper = await build();
    expect(
      wrapper.find('[data-test="confirm"]').attributes('disabled')
    ).toBeDefined();
    await wrapper.find('[data-test="confirm"]').trigger('click');
    expect(wrapper.emitted('confirm')).toBeUndefined();
  });

  it('emits the payload with the chosen base and the other as mergee', async () => {
    const wrapper = await build();
    await wrapper.find('[data-test="base-1"]').setValue(true);
    await wrapper.find('[data-test="confirm"]').trigger('click');
    expect(wrapper.emitted('confirm')[0]).toEqual([
      { projectId: 3, baseContactId: 1, mergeeContactId: 2 },
    ]);
  });

  it('swaps base and mergee when the second person is chosen', async () => {
    const wrapper = await build();
    await wrapper.find('[data-test="base-2"]').setValue(true);
    await wrapper.find('[data-test="confirm"]').trigger('click');
    expect(wrapper.emitted('confirm')[0]).toEqual([
      { projectId: 3, baseContactId: 2, mergeeContactId: 1 },
    ]);
  });
});
