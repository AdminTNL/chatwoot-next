export const ERROR_MESSAGES = {
  'no-account-found': 'LOGIN.OAUTH.NO_ACCOUNT_FOUND',
  'business-account-only': 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY',
  'saml-authentication-failed': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'saml-not-enabled': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'tnl-auth-failed': 'LOGIN.OAUTH.TNL_AUTH_FAILED',
};

// tnl-auth has priority: when it is on, the native Google button is hidden.
export const getLoginOptions = (config = {}) => {
  const allowedLoginMethods = config.allowedLoginMethods || ['email'];
  const showTnlAuth = Boolean(config.tnlAuthEnabled);
  const showGoogleOAuth =
    !showTnlAuth &&
    allowedLoginMethods.includes('google_oauth') &&
    Boolean(config.googleOAuthClientId);
  return {
    showGoogleOAuth,
    showTnlAuth,
    showSocialDivider: showGoogleOAuth || showTnlAuth,
  };
};
