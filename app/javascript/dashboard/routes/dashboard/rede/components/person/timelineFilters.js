// Tipos aceitos por GET people/:id/timeline (param `types`).
export const TIMELINE_TYPES = [
  'conversation',
  'call',
  'note',
  'temperature_change',
  'assignment_change',
];

export const PERIOD_SHORTCUTS = [7, 30, 90];

const pad = value => String(value).padStart(2, '0');

// Data local no formato YYYY-MM-DD (o que o filtro from/to espera).
export const toDateString = date =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;

// Valor do <input type="datetime-local"> (YYYY-MM-DDTHH:mm, hora local).
export const toDateTimeInput = date =>
  `${toDateString(date)}T${pad(date.getHours())}:${pad(date.getMinutes())}`;

// "Últimos N dias": de N dias atrás até hoje, ambos inclusivos.
export const periodShortcut = (days, now = new Date()) => {
  const start = new Date(now);
  start.setDate(start.getDate() - days);
  return { from: toDateString(start), to: toDateString(now) };
};

// Filtros da tela -> parâmetros da API, sem os vazios.
export const buildTimelineParams = filters => {
  const params = {};
  if (filters.projectId) params.project_id = filters.projectId;
  if (filters.from) params.from = filters.from;
  if (filters.to) params.to = filters.to;
  if (filters.types?.length) params.types = filters.types;
  return params;
};
