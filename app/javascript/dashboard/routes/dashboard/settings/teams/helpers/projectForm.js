// Mesma paleta e mesmo formato do backend (Rede::Project::COLOR_PALETTE e COLOR_FORMAT).
export const PROJECT_COLOR_PALETTE = [
  '#1F93FF',
  '#E5484D',
  '#30A46C',
  '#F5A524',
  '#8E4EC6',
  '#00A2C7',
  '#D6409F',
  '#6E56CF',
];

const HEX_COLOR_FORMAT = /^#[0-9a-fA-F]{6}$/;

export const isValidHexColor = value =>
  typeof value === 'string' && HEX_COLOR_FORMAT.test(value);

export const normalizeHexColor = value => {
  const trimmed = String(value ?? '').trim();
  if (!trimmed) return '';
  return trimmed.startsWith('#') ? trimmed : `#${trimmed}`;
};

// Devolve um objeto { campo: 'CODIGO' }; vazio quando válido.
export const validateProjectForm = ({ name, color }) => {
  const errors = {};
  if (!String(name ?? '').trim()) {
    errors.name = 'REQUIRED';
  }
  if (!isValidHexColor(color)) {
    errors.color = 'INVALID_HEX';
  }
  return errors;
};
