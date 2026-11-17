import { mount } from '@vue/test-utils';
import TemperatureBadge from '../TemperatureBadge.vue';
import { TEMPERATURES } from '../../../helpers/temperature';

const labels = {
  vapor: 'Steaming',
  quente: 'Hot',
  morno: 'Warm',
  frio: 'Cold',
  none: 'No temperature',
};

describe('TemperatureBadge', () => {
  Object.keys(labels).forEach(level => {
    it(`shows the label and the class for ${level}`, () => {
      const wrapper = mount(TemperatureBadge, { props: { level } });
      expect(wrapper.text()).toBe(labels[level]);
      TEMPERATURES[level].badgeClass
        .split(' ')
        .forEach(cls => expect(wrapper.classes()).toContain(cls));
    });
  });

  it('treats null as no temperature', () => {
    const wrapper = mount(TemperatureBadge, { props: { level: null } });
    expect(wrapper.text()).toBe('No temperature');
  });

  it('treats an unknown level as no temperature', () => {
    const wrapper = mount(TemperatureBadge, { props: { level: 'ardendo' } });
    expect(wrapper.text()).toBe('No temperature');
  });

  it('never renders without a label', () => {
    const wrapper = mount(TemperatureBadge);
    expect(wrapper.text()).not.toBe('');
  });
});
