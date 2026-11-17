import { mount } from '@vue/test-utils';
import CallDialog from '../CallDialog.vue';

const DialogStub = {
  props: ['title', 'isLoading'],
  emits: ['confirm', 'close'],
  template: '<div><slot /></div>',
  methods: { open() {}, close() {} },
};

const one = [{ id: 2, name: 'PE' }];
const two = [...one, { id: 3, name: 'PA' }];

const factory = (props = {}) =>
  mount(CallDialog, {
    props: {
      projects: two,
      frontsByProject: { 2: [{ id: 10, name: 'Campo' }] },
      authorName: 'Bia',
      ...props,
    },
    global: { stubs: { Dialog: DialogStub } },
  });

const confirm = async wrapper => {
  wrapper.findComponent(DialogStub).vm.$emit('confirm');
  await wrapper.vm.$nextTick();
};

describe('CallDialog', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-11-16T12:00:00Z'));
  });
  afterEach(() => vi.useRealTimers());

  it('requires project and answered', async () => {
    const wrapper = factory();
    wrapper.vm.open();
    await confirm(wrapper);
    expect(wrapper.emitted('submit')).toBeUndefined();
    expect(wrapper.text()).toContain('Choose a project.');
    expect(wrapper.text()).toContain('Say whether the call was answered.');
  });

  it('preselects the only project', async () => {
    const wrapper = factory({ projects: one });
    wrapper.vm.open();
    await wrapper.vm.$nextTick();
    expect(
      wrapper.find('[data-test="call-project"] select').element.value
    ).toBe('2');
  });

  it('blocks a future date', async () => {
    const wrapper = factory({ projects: one });
    wrapper.vm.open();
    await wrapper.find('[data-test="call-answered"] select').setValue('yes');
    await wrapper
      .find('input[data-test="call-occurred-at"]')
      .setValue('2026-11-16T13:00');
    await confirm(wrapper);
    expect(wrapper.emitted('submit')).toBeUndefined();
    expect(wrapper.text()).toContain('The date cannot be in the future.');
  });

  it('shows the logged user as a read only author', () => {
    const wrapper = factory();
    expect(wrapper.find('[data-test="call-author"]').text()).toContain('Bia');
    expect(wrapper.find('[data-test="call-author"] input').exists()).toBe(
      false
    );
  });

  it('emits the payload', async () => {
    const wrapper = factory();
    wrapper.vm.open();
    await wrapper.find('[data-test="call-project"] select').setValue('2');
    await wrapper.find('[data-test="call-front"] select').setValue('10');
    await wrapper.find('[data-test="call-answered"] select').setValue('no');
    await wrapper
      .find('input[data-test="call-occurred-at"]')
      .setValue('2026-11-16T09:30');
    await wrapper
      .find('[data-test="call-summary"] textarea')
      .setValue('caixa postal');
    await confirm(wrapper);
    expect(wrapper.emitted('submit')[0][0]).toEqual({
      projectId: 2,
      frontId: 10,
      answered: false,
      occurredAt: '2026-11-16T09:30:00.000Z',
      summary: 'caixa postal',
    });
  });

  it('defaults the date to now and omits the front', async () => {
    const wrapper = factory({ projects: one });
    wrapper.vm.open();
    await wrapper.find('[data-test="call-answered"] select').setValue('yes');
    await confirm(wrapper);
    const payload = wrapper.emitted('submit')[0][0];
    expect(payload.occurredAt).toBe('2026-11-16T12:00:00.000Z');
    expect(payload.frontId).toBeUndefined();
    expect(payload.answered).toBe(true);
  });
});
