import { mount } from '@vue/test-utils';
import NoteDialog from '../NoteDialog.vue';

const DialogStub = {
  props: ['title', 'isLoading'],
  emits: ['confirm', 'close'],
  template: '<div><slot /></div>',
  methods: { open() {}, close() {} },
};

const factory = (projects = [{ id: 2, name: 'PE' }]) =>
  mount(NoteDialog, {
    props: { projects, frontsByProject: { 2: [{ id: 10, name: 'Campo' }] } },
    global: { stubs: { Dialog: DialogStub } },
  });

const confirm = async wrapper => {
  wrapper.findComponent(DialogStub).vm.$emit('confirm');
  await wrapper.vm.$nextTick();
};

describe('NoteDialog', () => {
  it('requires the text', async () => {
    const wrapper = factory();
    wrapper.vm.open();
    await confirm(wrapper);
    expect(wrapper.emitted('submit')).toBeUndefined();
    expect(wrapper.text()).toContain('Write the note.');
  });

  it('emits the payload with the preselected project', async () => {
    const wrapper = factory();
    wrapper.vm.open();
    await wrapper.vm.$nextTick();
    await wrapper.find('[data-test="note-front"] select').setValue('10');
    await wrapper
      .find('[data-test="note-summary"] textarea')
      .setValue('pediu retorno');
    await confirm(wrapper);
    expect(wrapper.emitted('submit')[0][0]).toEqual({
      projectId: 2,
      frontId: 10,
      summary: 'pediu retorno',
    });
  });
});
