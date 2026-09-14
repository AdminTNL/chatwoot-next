import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import Sidebar from '../Sidebar.vue';

vi.mock('vue-router');

// Sidebar.vue statically imports several heavy, unrelated components
// (compose conversation, account switcher, profile menu, changelog widgets).
// component `stubs` alone only swap the render output, they don't stop the
// real module (and its own import graph, e.g. canned responses/macros
// settings routes) from being evaluated when Sidebar.vue is imported - which
// pulls in the full dashboard routes tree and crashes on a circular import.
// Mock the modules themselves so only the Reports-menu-relevant code path
// (Sidebar.vue + SidebarGroup.vue + provider.js, all real) gets exercised.
vi.mock(
  'dashboard/components-next/NewConversation/ComposeConversation.vue',
  () => ({
    default: { template: '<div><slot name="trigger" :isOpen="false" /></div>' },
  })
);
vi.mock('../SidebarAccountSwitcher.vue', () => ({
  default: { template: '<div />' },
}));
vi.mock('../SidebarProfileMenu.vue', () => ({
  default: { template: '<div />' },
}));
vi.mock('../SidebarChangelogCard.vue', () => ({
  default: { template: '<div />' },
}));
vi.mock('../SidebarChangelogButton.vue', () => ({
  default: { template: '<div />' },
}));
vi.mock('../ChannelLeaf.vue', () => ({
  default: { template: '<div />' },
}));
vi.mock('next/icon/ChannelIcon.vue', () => ({
  default: { template: '<div />' },
}));
vi.mock('next/icon/Logo.vue', () => ({
  default: { template: '<div />' },
}));
vi.mock('dashboard/components-next/button/Button.vue', () => ({
  default: { template: '<button />' },
}));

// NOTE: this test does not import reports.routes.js directly (not even to
// read its meta) - doing so crashes under Vitest with
// "Cannot read properties of undefined (reading 'routes')" at
// settings.routes.js:64, a pre-existing circular-import bug between
// reports.routes.js and settings.routes.js/dashboard.routes.js that exists
// independently of this spec's changes (reproduces on an unmodified
// checkout, and Sidebar.vue itself never imports that file - it only
// references route names as strings). Out of scope here; reported to the
// orchestrator separately. The permissions below are kept in sync by hand
// with app/javascript/dashboard/routes/dashboard/settings/reports/reports.routes.js.
const REPORT_ROUTE_PERMISSIONS = ['administrator', 'report_manage', 'agent'];

const REPORT_ROUTE_NAMES = [
  'account_overview_reports',
  'conversation_reports',
  'agent_reports_index',
  'label_reports_index',
  'inbox_reports_index',
  'team_reports_index',
  'csat_reports',
  'sla_reports',
  'bot_reports',
];

const routeMetaByName = Object.fromEntries(
  REPORT_ROUTE_NAMES.map(name => [
    name,
    { permissions: REPORT_ROUTE_PERMISSIONS },
  ])
);

const ADMIN_USER = {
  id: 1,
  accounts: [{ id: 1, role: 'administrator', permissions: ['administrator'] }],
};

const AGENT_USER = {
  id: 2,
  accounts: [{ id: 1, role: 'agent', permissions: ['agent'] }],
};

const CUSTOM_ROLE_REPORT_MANAGE_USER = {
  id: 3,
  accounts: [
    {
      id: 1,
      role: 'agent',
      custom_role_id: 10,
      permissions: ['report_manage', 'custom_role'],
    },
  ],
};

const CUSTOM_ROLE_NO_REPORTS_USER = {
  id: 4,
  accounts: [
    {
      id: 1,
      role: 'agent',
      custom_role_id: 11,
      permissions: ['contact_manage', 'custom_role'],
    },
  ],
};

const buildStore = currentUser =>
  createStore({
    getters: {
      getCurrentAccountId: () => 1,
      getCurrentUserID: () => currentUser.id,
      getCurrentUser: () => currentUser,
      getUISettings: () => ({}),
      'accounts/getAccount': () => () => ({ id: 1, name: 'Chatwoot' }),
      'accounts/isFeatureEnabledonAccount': () => () => true,
      'accounts/isRTL': () => false,
      'globalConfig/isACustomBrandedInstance': () => false,
      'globalConfig/isOnChatwootCloud': () => false,
      'inboxes/getInboxes': () => [],
      'labels/getLabelsOnSidebar': () => [],
      'teams/getMyTeams': () => [],
      'customViews/getContactCustomViews': () => [],
      'customViews/getConversationCustomViews': () => [],
      'sidebarSortPreferences/getSectionSort': () => () => null,
      'notifications/getUnreadCount': () => 0,
      'conversationUnreadCounts/getAllUnreadCount': () => 0,
      'conversationUnreadCounts/getInboxUnreadCount': () => () => 0,
      'conversationUnreadCounts/getLabelUnreadCount': () => () => 0,
      'conversationUnreadCounts/getTeamUnreadCount': () => () => 0,
      'conversationUnreadCounts/getMentionsUnreadCount': () => 0,
      'conversationUnreadCounts/getParticipatingUnreadCount': () => 0,
      'conversationUnreadCounts/getUnattendedUnreadCount': () => 0,
      'conversationUnreadCounts/getFolderUnreadCount': () => () => 0,
    },
    actions: {
      'labels/get': () => {},
      'inboxes/get': () => {},
      'notifications/unReadCount': () => {},
      'teams/get': () => {},
      'attributes/get': () => {},
      'customViews/get': () => {},
      'conversationUnreadCounts/clear': () => {},
      'conversationUnreadCounts/get': () => {},
      'sidebarSortPreferences/initialize': () => {},
      updateUISettings: () => {},
    },
  });

const mountSidebar = currentUser => {
  useRoute.mockReturnValue({
    params: { accountId: '1' },
    path: '/',
    name: null,
  });

  useRouter.mockReturnValue({
    resolve: to => ({
      path: '/',
      meta: (to && routeMetaByName[to.name]) || {},
    }),
    getRoutes: () =>
      Object.entries(routeMetaByName).map(([name, meta]) => ({ name, meta })),
    push: vi.fn(),
  });

  return mount(Sidebar, {
    global: {
      plugins: [buildStore(currentUser)],
      stubs: {
        RouterLink: { template: '<a><slot /></a>' },
      },
    },
  });
};

// The Reports group header renders its label in a `span.truncate` inside
// SidebarGroupHeader. Match the label exactly so child items such as
// "Reports SLA" (which also contain the word "Reports") don't false-positive.
const findReportsGroupHeader = wrapper =>
  wrapper.findAll('span.truncate').find(el => el.text().trim() === 'Reports');

describe('Sidebar - Reports menu permission', () => {
  it('shows the full Reports group to an administrator', () => {
    const wrapper = mountSidebar(ADMIN_USER);
    const header = findReportsGroupHeader(wrapper);

    expect(header).toBeTruthy();
  });

  it('shows the Reports group to a custom role user with report_manage', () => {
    const wrapper = mountSidebar(CUSTOM_ROLE_REPORT_MANAGE_USER);
    const header = findReportsGroupHeader(wrapper);

    expect(header).toBeTruthy();
  });

  it('shows the Reports group to a plain agent (scoped access after spec 010)', () => {
    const wrapper = mountSidebar(AGENT_USER);
    const header = findReportsGroupHeader(wrapper);

    expect(header).toBeTruthy();
  });

  it('hides the Reports group entirely for a user without any report permission', () => {
    const wrapper = mountSidebar(CUSTOM_ROLE_NO_REPORTS_USER);
    const header = findReportsGroupHeader(wrapper);

    expect(header).toBeFalsy();
  });

  it('keeps reports.routes.js meta.permissions in sync with what this spec asserts (no route-guard divergence)', async () => {
    // Read the file as text instead of importing it, to sidestep the
    // circular-import crash described above.
    const { readFileSync } = await import('node:fs');
    const { join } = await import('node:path');
    const routesFilePath = join(
      process.cwd(),
      'app/javascript/dashboard/routes/dashboard/settings/reports/reports.routes.js'
    );
    const source = readFileSync(routesFilePath, 'utf-8');
    const permissionArrays = [
      ...source.matchAll(/permissions:\s*(\[[^\]]*\])/g),
    ].map(([, arr]) => arr);

    expect(permissionArrays.length).toBeGreaterThan(0);
    permissionArrays.forEach(arr => {
      expect(arr).toContain("'administrator'");
      expect(arr).toContain("'report_manage'");
      expect(arr).toContain("'agent'");
    });
  });
});
