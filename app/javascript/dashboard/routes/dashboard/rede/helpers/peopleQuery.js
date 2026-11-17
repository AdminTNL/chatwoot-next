import { TEMPERATURE_LEVELS } from './temperature';

// Filtros da lista de pessoas na URL (spec 013, decisão 5).
// Ida: parâmetros da API -> route.query. Volta: route.query -> parâmetros da API.
// Valores inválidos vindos da URL são ignorados.
const ID_LIST_KEYS = ['project_ids', 'front_ids', 'responsible_ids'];
const INT_KEYS = ['no_contact_days', 'page', 'per_page'];
const BOOL_KEYS = ['has_front', 'front_pending', 'include_closed'];
const TEXT_KEYS = ['q', 'city'];
export const SORT_VALUES = [
  'last_contact_at',
  '-last_contact_at',
  'name',
  '-name',
  'temperature',
  '-temperature',
];

const asArray = value => (Array.isArray(value) ? value : [value]);

const splitList = value =>
  asArray(value)
    .filter(item => item !== undefined && item !== null)
    .flatMap(item => String(item).split(','))
    .map(item => item.trim())
    .filter(Boolean);

const splitText = value => {
  const first = Array.isArray(value) ? value[0] : value;
  return typeof first === 'string' ? first.trim() : '';
};

const toPositiveInt = value => {
  const text = String(value).trim();
  if (!/^\d+$/.test(text)) return null;
  const number = Number(text);
  return number > 0 ? number : null;
};

// "Sem frente" e "Sem responsável" viajam como `none` junto dos ids.
const NONE_KEYS = ['front_ids', 'responsible_ids'];

const toIdList = (value, allowNone = false) =>
  splitList(value)
    .map(item => (allowNone && item === 'none' ? 'none' : toPositiveInt(item)))
    .filter(Boolean);

export const paramsToQuery = (params = {}) => {
  const query = {};

  ID_LIST_KEYS.forEach(key => {
    const ids = asArray(params[key] ?? []).filter(Boolean);
    if (ids.length) query[key] = ids.join(',');
  });

  const temperatures = asArray(params.temperatures ?? []).filter(Boolean);
  if (temperatures.length) query.temperatures = temperatures.join(',');

  TEXT_KEYS.forEach(key => {
    const text = typeof params[key] === 'string' ? params[key].trim() : '';
    if (text) query[key] = text;
  });

  INT_KEYS.forEach(key => {
    if (params[key] !== undefined && params[key] !== null) {
      query[key] = String(params[key]);
    }
  });

  BOOL_KEYS.forEach(key => {
    if (params[key] === true) query[key] = 'true';
  });

  if (params.sort) query.sort = params.sort;

  return query;
};

export const queryToParams = (query = {}) => {
  const params = {};

  ID_LIST_KEYS.forEach(key => {
    const ids = toIdList(query[key] ?? [], NONE_KEYS.includes(key));
    if (ids.length) params[key] = ids;
  });

  const temperatures = splitList(query.temperatures ?? []).filter(level =>
    TEMPERATURE_LEVELS.includes(level)
  );
  if (temperatures.length) params.temperatures = temperatures;

  TEXT_KEYS.forEach(key => {
    const text = splitText(query[key]);
    if (text) params[key] = text;
  });

  INT_KEYS.forEach(key => {
    const number = query[key] === undefined ? null : toPositiveInt(query[key]);
    if (number) params[key] = number;
  });

  BOOL_KEYS.forEach(key => {
    if (query[key] === 'true') params[key] = true;
  });

  if (SORT_VALUES.includes(query.sort)) params.sort = query.sort;

  return params;
};
