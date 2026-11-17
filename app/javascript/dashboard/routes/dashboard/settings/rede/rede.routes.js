import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import ApiTokens from './ApiTokens.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/rede'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: to => ({
            name: 'settings_rede_api_tokens',
            params: to.params,
          }),
        },
        {
          path: 'api-tokens',
          name: 'settings_rede_api_tokens',
          component: ApiTokens,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
