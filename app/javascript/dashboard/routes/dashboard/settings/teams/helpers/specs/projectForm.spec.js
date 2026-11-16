import {
  PROJECT_COLOR_PALETTE,
  isValidHexColor,
  normalizeHexColor,
  validateProjectForm,
} from '../projectForm';

describe('#PROJECT_COLOR_PALETTE', () => {
  it('has the 8 colors of the backend palette, all valid', () => {
    expect(PROJECT_COLOR_PALETTE).toHaveLength(8);
    PROJECT_COLOR_PALETTE.forEach(color =>
      expect(isValidHexColor(color)).toBe(true)
    );
  });
});

describe('#isValidHexColor', () => {
  it('accepts #RRGGBB only', () => {
    expect(isValidHexColor('#1F93FF')).toBe(true);
    expect(isValidHexColor('#1f93ff')).toBe(true);
    expect(isValidHexColor('1F93FF')).toBe(false);
    expect(isValidHexColor('#FFF')).toBe(false);
    expect(isValidHexColor('#GGGGGG')).toBe(false);
    expect(isValidHexColor('')).toBe(false);
    expect(isValidHexColor(null)).toBe(false);
  });
});

describe('#normalizeHexColor', () => {
  it('trims and adds the leading hash', () => {
    expect(normalizeHexColor(' 1f93ff ')).toBe('#1f93ff');
    expect(normalizeHexColor('#1F93FF')).toBe('#1F93FF');
  });
});

describe('#validateProjectForm', () => {
  it('requires a name', () => {
    expect(validateProjectForm({ name: '  ', color: '#1F93FF' })).toEqual({
      name: 'REQUIRED',
    });
  });

  it('rejects an invalid color', () => {
    expect(validateProjectForm({ name: 'Mobiliza', color: '#12' })).toEqual({
      color: 'INVALID_HEX',
    });
  });

  it('returns no errors for valid data', () => {
    expect(validateProjectForm({ name: 'Mobiliza', color: '#1F93FF' })).toEqual(
      {}
    );
  });
});
