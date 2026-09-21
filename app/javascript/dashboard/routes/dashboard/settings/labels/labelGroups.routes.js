import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import LabelGroupsIndex from './LabelGroupsIndex.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/labels/categories'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'labels_categories_list',
          meta: {
            featureFlag: FEATURE_FLAGS.LABELS,
            permissions: ['administrator'],
          },
          component: LabelGroupsIndex,
        },
      ],
    },
  ],
};
