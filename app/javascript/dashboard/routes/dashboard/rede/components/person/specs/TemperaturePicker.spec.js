import { mount } from '@vue/test-utils';
import TemperaturePicker from '../TemperaturePicker.vue';

const factory = (props = {}) =>
  mount(TemperaturePicker, { props: { modelValue: 'quente', ...props } });

const select = wrapper =>
  wrapper.find('[data-test="temperature-select"] select');

describe('TemperaturePicker', () => {
  it('offers the four levels plus no temperature, all with labels', () => {
    const labels = factory()
      .findAll('[data-test="temperature-select"] option')
      .map(option => option.text());
    expect(labels).toEqual([
      'Steaming',
      'Hot',
      'Warm',
      'Cold',
      'No temperature',
    ]);
  });

  it('emits level and note', async () => {
    const wrapper = factory();
    await select(wrapper).setValue('morno');
    await wrapper
      .find('input[data-test="temperature-note"]')
      .setValue('esfriou');
    await wrapper.find('[data-test="temperature-save"]').trigger('click');
    expect(wrapper.emitted('save')[0][0]).toEqual({
      level: 'morno',
      note: 'esfriou',
    });
  });

  it('emits null for no temperature and omits an empty note', async () => {
    const wrapper = factory();
    await select(wrapper).setValue('none');
    await wrapper.find('[data-test="temperature-save"]').trigger('click');
    expect(wrapper.emitted('save')[0][0]).toEqual({ level: null, note: null });
  });

  it('does not save the same level without a note', async () => {
    const wrapper = factory();
    await wrapper.find('[data-test="temperature-save"]').trigger('click');
    expect(wrapper.emitted('save')).toBeUndefined();
  });

  it('starts as no temperature when the value is null', () => {
    const wrapper = factory({ modelValue: null });
    expect(select(wrapper).element.value).toBe('none');
  });
});
