import { mount } from '@vue/test-utils';
import RecentChanges from '../RecentChanges.vue';

const RouterLink = {
  props: ['to'],
  template: '<a :data-to="JSON.stringify(to)"><slot /></a>',
};

const now = Date.now();
const ago = ms => new Date(now - ms).toISOString();

const change = overrides => ({
  type: 'temperature_change',
  occurredAt: ago(2 * 3600 * 1000),
  front: { id: 3, name: 'Field' },
  author: null,
  project: { id: 1, name: 'PE', color: '#ff0000' },
  contact: { id: 7, name: 'Maria Silva' },
  data: { from: 'morno', to: 'quente' },
  ...overrides,
});

const mountList = changes =>
  mount(RecentChanges, {
    props: { changes },
    global: { stubs: { RouterLink } },
  });

describe('RecentChanges', () => {
  it('shows the empty state', () => {
    const wrapper = mountList([]);
    expect(wrapper.text()).toContain('Nothing changed in the last 7 days.');
  });

  it('links the person to the person page', () => {
    const wrapper = mountList([change()]);
    const link = wrapper.find('a');
    expect(link.text()).toContain('Maria Silva');
    expect(JSON.parse(link.attributes('data-to'))).toEqual({
      name: 'rede_person',
      params: { contactId: 7 },
    });
  });

  it('shows project, front and temperature labels', () => {
    const text = mountList([change()]).text();
    expect(text).toContain('PE');
    expect(text).toContain('Field');
    expect(text).toContain('Warm');
    expect(text).toContain('Hot');
  });

  it('shows a relative time', () => {
    expect(mountList([change()]).text()).toMatch(/2 hours ago/);
  });

  it('handles participation_joined without front', () => {
    const wrapper = mountList([
      change({ type: 'participation_joined', front: null, data: {} }),
    ]);
    expect(wrapper.findAll('[data-test="change"]')).toHaveLength(1);
    expect(wrapper.text()).toContain('joined');
  });

  it('tolerates an unknown event type and missing fields', () => {
    const wrapper = mountList([
      change({ type: 'brand_new', front: undefined, data: undefined }),
    ]);
    expect(wrapper.findAll('[data-test="change"]')).toHaveLength(1);
    expect(wrapper.text()).toContain('Maria Silva');
  });

  it('treats a missing previous level as no temperature', () => {
    const text = mountList([
      change({ data: { from: null, to: 'vapor' } }),
    ]).text();
    expect(text).toContain('No temperature');
    expect(text).toContain('Steaming');
  });
});
