import {
  TEMPERATURE_LEVELS,
  TEMPERATURES,
  getTemperature,
} from '../temperature';

describe('rede temperature helper', () => {
  it('keeps the order from hottest to none', () => {
    expect(TEMPERATURE_LEVELS).toEqual([
      'vapor',
      'quente',
      'morno',
      'frio',
      'none',
    ]);
  });

  it('gives every level a label key and tailwind classes', () => {
    TEMPERATURE_LEVELS.forEach(level => {
      const item = TEMPERATURES[level];
      expect(item.labelKey).toBe(`REDE.TEMPERATURE.${level.toUpperCase()}`);
      expect(item.rowClass).toMatch(/\bbg-/);
      expect(item.badgeClass).toMatch(/\bbg-/);
      expect(item.badgeClass).toMatch(/\btext-/);
    });
  });

  it('uses design system tokens, never raw hex', () => {
    TEMPERATURE_LEVELS.forEach(level => {
      const { rowClass, badgeClass } = TEMPERATURES[level];
      expect(`${rowClass} ${badgeClass}`).not.toMatch(/#[0-9a-f]{3,6}/i);
    });
    expect(TEMPERATURES.vapor.badgeClass).toContain('n-ruby');
    expect(TEMPERATURES.quente.badgeClass).toContain('n-amber');
    expect(TEMPERATURES.frio.badgeClass).toContain('n-slate');
  });

  it('getTemperature falls back to none', () => {
    expect(getTemperature('quente')).toBe(TEMPERATURES.quente);
    expect(getTemperature(null)).toBe(TEMPERATURES.none);
    expect(getTemperature('xyz')).toBe(TEMPERATURES.none);
  });
});
