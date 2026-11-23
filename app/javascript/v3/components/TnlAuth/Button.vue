<script setup>
import { computed } from 'vue';

// The login starts on the server (state + PKCE live in the Rails session),
// so this is a plain link: the front never knows the issuer or the client.
const LOGIN_START_PATH = '/tnl_auth/login';

const isGoogle = computed(
  () => window.chatwootConfig.tnlAuthProvider === 'google'
);
</script>

<template>
  <div class="flex flex-col">
    <a
      :href="LOGIN_START_PATH"
      class="inline-flex justify-center w-full px-4 py-3 bg-n-background dark:bg-n-solid-3 items-center rounded-md shadow-sm ring-1 ring-inset ring-n-container dark:ring-n-container focus:outline-offset-0 hover:bg-n-alpha-2 dark:hover:bg-n-alpha-2"
    >
      <span v-if="isGoogle" class="i-logos-google-icon h-6" />
      <span v-else class="i-lucide-log-in size-5 text-n-slate-11" />
      <span class="ml-2 text-base font-medium text-n-slate-12">
        {{
          isGoogle
            ? $t('LOGIN.OAUTH.GOOGLE_LOGIN')
            : $t('LOGIN.OAUTH.TNL_AUTH_LOGIN')
        }}
      </span>
    </a>
  </div>
</template>
