import { mount } from '@vue/test-utils';
import TemperatureBars from '../TemperatureBars.vue';

const counts = { vapor: 1, quente: 2, morno: 3, frio: 4, none: 10 };

const mountBars = props =>
  mount(TemperatureBars, { props: { counts, ...props } });

const rows = wrapper => wrapper.findAll('[data-level]');
const barWidth = (wrapper, level) =>
  wrapper.find(`[data-level="${level}"] [data-test="bar"]`).element.style.width;

describe('TemperatureBars', () => {
  it('lists levels in order, ending with no temperature', () => {
    const wrapper = mountBars();
    expect(rows(wrapper).map(r => r.attributes('data-level'))).toEqual([
      'vapor',
      'quente',
      'morno',
      'frio',
      'none',
    ]);
  });

  it('always shows the label next to the count', () => {
    const wrapper = mountBars();
    expect(wrapper.find('[data-level="vapor"]').text()).toContain('Steaming');
    expect(wrapper.find('[data-level="vapor"]').text()).toContain('1');
    expect(wrapper.find('[data-level="none"]').text()).toContain(
      'No temperature'
    );
    expect(wrapper.find('[data-level="none"]').text()).toContain('10');
  });

  it('sizes bars proportionally to the total', () => {
    const wrapper = mountBars();
    expect(barWidth(wrapper, 'none')).toBe('50%');
    expect(barWidth(wrapper, 'vapor')).toBe('5%');
  });

  it('keeps a minimum width for tiny non-zero counts', () => {
    const wrapper = mountBars({ counts: { vapor: 1, none: 1000 } });
    expect(barWidth(wrapper, 'vapor')).toBe('2%');
    expect(barWidth(wrapper, 'frio')).toBe('0%');
  });

  it('keeps the none row and zero width when everything is zero', () => {
    const wrapper = mountBars({
      counts: { vapor: 0, quente: 0, morno: 0, frio: 0, none: 0 },
    });
    expect(rows(wrapper)).toHaveLength(5);
    expect(barWidth(wrapper, 'vapor')).toBe('0%');
    expect(barWidth(wrapper, 'none')).toBe('0%');
  });

  it('tolerates missing counts', () => {
    const wrapper = mountBars({ counts: {} });
    expect(rows(wrapper)).toHaveLength(5);
    expect(barWidth(wrapper, 'frio')).toBe('0%');
  });

  it('emits the level when a row is clicked', async () => {
    const wrapper = mountBars();
    await wrapper.find('[data-level="morno"]').trigger('click');
    expect(wrapper.emitted('select')).toEqual([['morno']]);
    await wrapper.find('[data-level="none"]').trigger('click');
    expect(wrapper.emitted('select')[1]).toEqual(['none']);
  });
});
