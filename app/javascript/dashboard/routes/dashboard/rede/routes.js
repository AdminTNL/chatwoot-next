import { frontendURL } from '../../../helper/URLHelper';
import OverviewPage from './pages/OverviewPage.vue';
import PeoplePage from './pages/PeoplePage.vue';
import PersonPage from './pages/PersonPage.vue';
import QualityPage from './pages/QualityPage.vue';

const defaultMeta = { permissions: ['administrator', 'agent'] };
// Qualidade dos dados é só do admin: o item nem aparece na sidebar para agente.
const adminMeta = { permissions: ['administrator'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/crm'),
    redirect: to => ({ name: 'rede_overview', params: to.params }),
  },
  {
    path: frontendURL('accounts/:accountId/crm/overview'),
    name: 'rede_overview',
    component: OverviewPage,
    meta: defaultMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/people'),
    name: 'rede_people',
    component: PeoplePage,
    meta: defaultMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/people/:contactId'),
    name: 'rede_person',
    component: PersonPage,
    meta: defaultMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/quality'),
    name: 'rede_quality',
    component: QualityPage,
    meta: adminMeta,
  },
];
