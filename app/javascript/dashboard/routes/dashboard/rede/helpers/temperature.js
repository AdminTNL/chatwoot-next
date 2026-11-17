// Ordem da mais quente para a sem temperatura. A cor nunca vem sozinha:
// a tela sempre mostra o rótulo (labelKey) junto da etiqueta.
export const TEMPERATURE_LEVELS = ['vapor', 'quente', 'morno', 'frio', 'none'];

export const TEMPERATURES = {
  vapor: {
    level: 'vapor',
    labelKey: 'REDE.TEMPERATURE.VAPOR',
    rowClass: 'bg-n-ruby-2',
    badgeClass: 'bg-n-ruby-3 text-n-ruby-11',
  },
  quente: {
    level: 'quente',
    labelKey: 'REDE.TEMPERATURE.QUENTE',
    rowClass: 'bg-n-amber-2',
    badgeClass: 'bg-n-amber-3 text-n-amber-11',
  },
  morno: {
    level: 'morno',
    labelKey: 'REDE.TEMPERATURE.MORNO',
    rowClass: 'bg-n-teal-2',
    badgeClass: 'bg-n-teal-3 text-n-teal-11',
  },
  frio: {
    level: 'frio',
    labelKey: 'REDE.TEMPERATURE.FRIO',
    rowClass: 'bg-n-slate-2',
    badgeClass: 'bg-n-slate-3 text-n-slate-11',
  },
  none: {
    level: 'none',
    labelKey: 'REDE.TEMPERATURE.NONE',
    rowClass: 'bg-n-alpha-1',
    badgeClass: 'bg-n-alpha-2 text-n-slate-11',
  },
};

export const getTemperature = level => TEMPERATURES[level] || TEMPERATURES.none;
