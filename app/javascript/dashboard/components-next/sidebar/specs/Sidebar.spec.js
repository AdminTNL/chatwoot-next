import { reactive } from 'vue';
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
// Rendered with the real label/badgeCount so Channels-section tests below
// can assert on which inboxes are shown and in what order, the same way
// findTeamLeafLabels does for the Teams section above.
vi.mock('../ChannelLeaf.vue', () => ({
  default: {
    props: ['label', 'active', 'inbox', 'badgeCount'],
    template:
      '<div class="channel-leaf-stub" :data-badge-count="badgeCount">{{ label }}</div>',
  },
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

const buildStore = (
  currentUser,
  { myTeams = [], teams = [], inboxes = [], labels = [] } = {}
) =>
  createStore({
    getters: {
      getCurrentAccountId: () => 1,
      getCurrentUserID: () => currentUser.id,
      getCurrentUser: () => currentUser,
      getCurrentRole: () => currentUser.accounts[0].role,
      getUISettings: () => ({}),
      'accounts/getAccount': () => () => ({ id: 1, name: 'Chatwoot' }),
      'accounts/isFeatureEnabledonAccount': () => () => true,
      'accounts/isRTL': () => false,
      'globalConfig/isACustomBrandedInstance': () => false,
      'globalConfig/isOnChatwootCloud': () => false,
      'inboxes/getInboxes': () => inboxes,
      'labels/getLabelsOnSidebar': () => labels,
      'teams/getMyTeams': () => myTeams,
      'teams/getTeams': () => teams,
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

const mountSidebar = (currentUser, storeOptions, routeOverrides = {}) => {
  useRoute.mockReturnValue({
    params: { accountId: '1' },
    path: '/',
    name: null,
    ...routeOverrides,
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
      plugins: [buildStore(currentUser, storeOptions)],
      stubs: {
        RouterLink: { template: '<a><slot /></a>' },
      },
    },
  });
};

// `useAccount()` (and therefore Sidebar.vue) reads `route` once via
// `useRoute()` at setup time. To simulate navigating between routes without
// remounting the component (so we can assert the Channels list updates
// reactively), the route object handed to `useRoute.mockReturnValue` must be
// a Vue `reactive()` object - mutating a plain object's properties after
// mount would not trigger the component's computed properties to re-run.
const mountSidebarWithReactiveRoute = (
  currentUser,
  storeOptions,
  initialRoute
) => {
  const route = reactive({
    params: { accountId: '1' },
    path: '/',
    name: null,
    ...initialRoute,
  });
  useRoute.mockReturnValue(route);

  useRouter.mockReturnValue({
    resolve: to => ({
      path: '/',
      meta: (to && routeMetaByName[to.name]) || {},
    }),
    getRoutes: () =>
      Object.entries(routeMetaByName).map(([name, meta]) => ({ name, meta })),
    push: vi.fn(),
  });

  const wrapper = mount(Sidebar, {
    global: {
      plugins: [buildStore(currentUser, storeOptions)],
      stubs: {
        RouterLink: { template: '<a><slot /></a>' },
      },
    },
  });

  return { wrapper, route };
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

// The Teams group header renders its label in a `span.truncate` inside
// SidebarGroupHeader, same structure as the Reports group above.
const findTeamsGroupHeader = wrapper =>
  wrapper.findAll('span.truncate').find(el => el.text().trim() === 'Teams');

// Team leaves render their label in a `div.truncate` inside
// SidebarGroupLeaf (see SidebarGroupLeaf.vue).
const findTeamLeafLabels = wrapper =>
  wrapper
    .findAll('div.truncate')
    .map(el => el.text().trim())
    .filter(Boolean);

describe('Sidebar - Teams section (admin sees all account teams)', () => {
  const memberTeamA = { id: 1, name: 'Team A', is_member: true };
  const memberTeamB = { id: 2, name: 'Team B', is_member: true };
  const nonMemberTeamC = { id: 3, name: 'Team C', is_member: false };

  it('shows every account team to an admin who is not a member of any of them', () => {
    const wrapper = mountSidebar(ADMIN_USER, {
      myTeams: [],
      teams: [memberTeamA, memberTeamB, nonMemberTeamC],
    });

    expect(findTeamsGroupHeader(wrapper)).toBeTruthy();
    const labels = findTeamLeafLabels(wrapper);
    expect(labels).toEqual(
      expect.arrayContaining(['Team A', 'Team B', 'Team C'])
    );
  });

  it('shows every account team to an admin who is only a member of some of them, without duplicates', () => {
    const wrapper = mountSidebar(ADMIN_USER, {
      myTeams: [memberTeamA],
      teams: [memberTeamA, memberTeamB, nonMemberTeamC],
    });

    const labels = findTeamLeafLabels(wrapper);
    const teamLabels = labels.filter(label => label.startsWith('Team '));

    expect(teamLabels.sort()).toEqual(['Team A', 'Team B', 'Team C']);
  });

  it('shows only the teams the agent is a member of, without regression', () => {
    const wrapper = mountSidebar(AGENT_USER, {
      myTeams: [memberTeamA, memberTeamB],
      teams: [memberTeamA, memberTeamB, nonMemberTeamC],
    });

    expect(findTeamsGroupHeader(wrapper)).toBeTruthy();
    const labels = findTeamLeafLabels(wrapper);

    expect(labels).toEqual(expect.arrayContaining(['Team A', 'Team B']));
    expect(labels).not.toContain('Team C');
  });

  it('does not render the Teams section for an admin when the account has no teams', () => {
    const wrapper = mountSidebar(ADMIN_USER, { myTeams: [], teams: [] });

    expect(findTeamsGroupHeader(wrapper)).toBeFalsy();
  });

  it('does not render the Teams section for an agent when the account has no teams', () => {
    const wrapper = mountSidebar(AGENT_USER, { myTeams: [], teams: [] });

    expect(findTeamsGroupHeader(wrapper)).toBeFalsy();
  });
});

// Channel leaves render their label inside the `ChannelLeaf` stub above
// (`.channel-leaf-stub`), unlike Team/Folder/Label leaves which go through
// the default `SidebarGroupLeaf` (`div.truncate`).
const findChannelLabels = wrapper =>
  wrapper
    .findAll('.channel-leaf-stub')
    .map(el => el.text().trim())
    .filter(Boolean);

describe('Sidebar - Channels section filtered by active team route', () => {
  const teamX = { id: 10, name: 'Team X', is_member: true };
  const teamY = { id: 20, name: 'Team Y', is_member: true };
  const teamZ = { id: 30, name: 'Team Z (no inboxes)', is_member: true };

  const inboxOfX = { id: 1, name: 'Inbox X1', team_id: 10 };
  const otherInboxOfX = { id: 2, name: 'Inbox X2', team_id: 10 };
  const inboxOfY = { id: 3, name: 'Inbox Y1', team_id: 20 };
  const inboxWithNoTeam = { id: 4, name: 'Inbox No Team', team_id: null };

  const allTeams = [teamX, teamY, teamZ];
  const allInboxes = [inboxOfX, otherInboxOfX, inboxOfY, inboxWithNoTeam];

  it('shows all accessible inboxes when the active route is not a team route', () => {
    const wrapper = mountSidebar(
      ADMIN_USER,
      { myTeams: allTeams, teams: allTeams, inboxes: allInboxes },
      { name: 'home' }
    );

    expect(findChannelLabels(wrapper)).toEqual(
      expect.arrayContaining([
        'Inbox X1',
        'Inbox X2',
        'Inbox Y1',
        'Inbox No Team',
      ])
    );
  });

  it('shows only the inboxes of the active team on the team_conversations route', () => {
    const wrapper = mountSidebar(
      ADMIN_USER,
      { myTeams: allTeams, teams: allTeams, inboxes: allInboxes },
      { name: 'team_conversations', params: { accountId: '1', teamId: '10' } }
    );

    const labels = findChannelLabels(wrapper);
    expect(labels).toEqual(expect.arrayContaining(['Inbox X1', 'Inbox X2']));
    expect(labels).not.toContain('Inbox Y1');
    expect(labels).not.toContain('Inbox No Team');
  });

  it('applies the same filter on a deep link into a team conversation (conversations_through_team)', () => {
    const wrapper = mountSidebar(
      ADMIN_USER,
      { myTeams: allTeams, teams: allTeams, inboxes: allInboxes },
      {
        name: 'conversations_through_team',
        params: { accountId: '1', teamId: '20' },
      }
    );

    const labels = findChannelLabels(wrapper);
    expect(labels).toEqual(['Inbox Y1']);
  });

  it('updates the Channels list reactively when navigating from one team to another', async () => {
    const { wrapper, route } = mountSidebarWithReactiveRoute(
      ADMIN_USER,
      { myTeams: allTeams, teams: allTeams, inboxes: allInboxes },
      { name: 'team_conversations', params: { accountId: '1', teamId: '10' } }
    );

    expect(findChannelLabels(wrapper)).toEqual(
      expect.arrayContaining(['Inbox X1', 'Inbox X2'])
    );
    expect(findChannelLabels(wrapper)).not.toContain('Inbox Y1');

    route.params = { accountId: '1', teamId: '20' };
    await wrapper.vm.$nextTick();

    const labelsAfterNavigation = findChannelLabels(wrapper);
    expect(labelsAfterNavigation).toEqual(['Inbox Y1']);
    expect(labelsAfterNavigation).not.toContain('Inbox X1');
    expect(labelsAfterNavigation).not.toContain('Inbox X2');
  });

  it('restores the full inbox list after leaving the team route', async () => {
    const { wrapper, route } = mountSidebarWithReactiveRoute(
      ADMIN_USER,
      { myTeams: allTeams, teams: allTeams, inboxes: allInboxes },
      { name: 'team_conversations', params: { accountId: '1', teamId: '10' } }
    );

    expect(findChannelLabels(wrapper)).not.toContain('Inbox Y1');

    route.name = 'home';
    route.params = { accountId: '1' };
    await wrapper.vm.$nextTick();

    expect(findChannelLabels(wrapper)).toEqual(
      expect.arrayContaining([
        'Inbox X1',
        'Inbox X2',
        'Inbox Y1',
        'Inbox No Team',
      ])
    );
  });

  it('shows an empty Channels list without erroring when the active team has no inboxes', () => {
    const wrapper = mountSidebar(
      ADMIN_USER,
      { myTeams: allTeams, teams: allTeams, inboxes: allInboxes },
      { name: 'team_conversations', params: { accountId: '1', teamId: '30' } }
    );

    expect(findChannelLabels(wrapper)).toEqual([]);
  });

  it('shows an empty Channels list without erroring when the route teamId matches no existing inbox', () => {
    const wrapper = mountSidebar(
      ADMIN_USER,
      { myTeams: allTeams, teams: allTeams, inboxes: allInboxes },
      {
        name: 'team_conversations',
        params: { accountId: '1', teamId: '999999' },
      }
    );

    expect(findChannelLabels(wrapper)).toEqual([]);
  });

  it('keeps unread-count sorting and per-inbox badges correct over the filtered list', () => {
    const inboxLowUnread = {
      id: 5,
      name: 'Low Unread',
      team_id: 10,
      created_at: 100,
    };
    const inboxHighUnread = {
      id: 6,
      name: 'High Unread',
      team_id: 10,
      created_at: 200,
    };

    useRoute.mockReturnValue({
      params: { accountId: '1', teamId: '10' },
      path: '/',
      name: 'team_conversations',
    });
    useRouter.mockReturnValue({
      resolve: () => ({ path: '/', meta: {} }),
      getRoutes: () => [],
      push: vi.fn(),
    });

    const wrapper = mount(Sidebar, {
      global: {
        plugins: [
          createStore({
            getters: {
              getCurrentAccountId: () => 1,
              getCurrentUserID: () => ADMIN_USER.id,
              getCurrentUser: () => ADMIN_USER,
              getCurrentRole: () => ADMIN_USER.accounts[0].role,
              getUISettings: () => ({}),
              'accounts/getAccount': () => () => ({ id: 1, name: 'Chatwoot' }),
              'accounts/isFeatureEnabledonAccount': () => () => true,
              'accounts/isRTL': () => false,
              'globalConfig/isACustomBrandedInstance': () => false,
              'globalConfig/isOnChatwootCloud': () => false,
              'inboxes/getInboxes': () => [inboxLowUnread, inboxHighUnread],
              'labels/getLabelsOnSidebar': () => [],
              'teams/getMyTeams': () => [teamX],
              'teams/getTeams': () => [teamX],
              'customViews/getContactCustomViews': () => [],
              'customViews/getConversationCustomViews': () => [],
              'sidebarSortPreferences/getSectionSort': () => section =>
                section === 'channels' ? 'unread_count_desc' : null,
              'notifications/getUnreadCount': () => 0,
              'conversationUnreadCounts/getAllUnreadCount': () => 0,
              'conversationUnreadCounts/getInboxUnreadCount': () => id =>
                id === inboxHighUnread.id ? 9 : 1,
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
          }),
        ],
        stubs: {
          RouterLink: { template: '<a><slot /></a>' },
        },
      },
    });

    expect(findChannelLabels(wrapper)).toEqual(['High Unread', 'Low Unread']);
  });
});

// Label leaves render through the default SidebarGroupLeaf (`div.truncate`),
// same as Team leaves - but the exact same label titles are also rendered,
// unfiltered, by the unrelated "Tagged with" contacts section. Scope the
// lookup to the "Labels" conversations sub-group (found via its header text)
// so this only asserts on the section under test.
const findLabelLeafLabels = wrapper => {
  const header = wrapper
    .findAll('span.truncate')
    .find(el => el.text().trim() === 'Labels');
  if (!header) return [];

  const section = header.element.closest('li.group\\/sidebar-section');
  if (!section) return [];

  return Array.from(section.querySelectorAll('div.truncate'))
    .map(el => el.textContent.trim())
    .filter(Boolean);
};

describe('Sidebar - Labels section filtered by active team route', () => {
  const teamX = { id: 10, name: 'Team X', is_member: true };
  const teamY = { id: 20, name: 'Team Y', is_member: true };

  const labelOfX = {
    id: 1,
    title: 'urgent-x',
    team_id: 10,
    show_on_sidebar: true,
  };
  const otherLabelOfX = {
    id: 2,
    title: 'billing-x',
    team_id: 10,
    show_on_sidebar: true,
  };
  const labelOfY = {
    id: 3,
    title: 'urgent-y',
    team_id: 20,
    show_on_sidebar: true,
  };
  const globalLabel = {
    id: 4,
    title: 'vip',
    team_id: null,
    show_on_sidebar: true,
  };

  const allTeams = [teamX, teamY];
  const allLabels = [labelOfX, otherLabelOfX, labelOfY, globalLabel];

  it('shows all labels, including global ones, when the active route is not a team route', () => {
    const wrapper = mountSidebar(
      ADMIN_USER,
      { myTeams: allTeams, teams: allTeams, labels: allLabels },
      { name: 'home' }
    );

    expect(findLabelLeafLabels(wrapper)).toEqual(
      expect.arrayContaining(['urgent-x', 'billing-x', 'urgent-y', 'vip'])
    );
  });

  it('shows only the labels of the active team on the team_conversations route, hiding global labels', () => {
    const wrapper = mountSidebar(
      ADMIN_USER,
      { myTeams: allTeams, teams: allTeams, labels: allLabels },
      { name: 'team_conversations', params: { accountId: '1', teamId: '10' } }
    );

    const labels = findLabelLeafLabels(wrapper);
    expect(labels).toEqual(expect.arrayContaining(['urgent-x', 'billing-x']));
    expect(labels).not.toContain('urgent-y');
    expect(labels).not.toContain('vip');
  });

  it('restores the full label list, including global ones, after leaving the team route', async () => {
    const { wrapper, route } = mountSidebarWithReactiveRoute(
      ADMIN_USER,
      { myTeams: allTeams, teams: allTeams, labels: allLabels },
      { name: 'team_conversations', params: { accountId: '1', teamId: '10' } }
    );

    expect(findLabelLeafLabels(wrapper)).not.toContain('vip');

    route.name = 'home';
    route.params = { accountId: '1' };
    await wrapper.vm.$nextTick();

    expect(findLabelLeafLabels(wrapper)).toEqual(
      expect.arrayContaining(['urgent-x', 'billing-x', 'urgent-y', 'vip'])
    );
  });
});
