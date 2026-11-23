import { ERROR_MESSAGES, getLoginOptions } from './loginOptions';

describe('getLoginOptions', () => {
  const google = {
    allowedLoginMethods: ['email', 'google_oauth'],
    googleOAuthClientId: 'id',
  };

  it('keeps the current behaviour without tnl-auth', () => {
    expect(getLoginOptions(google)).toEqual({
      showGoogleOAuth: true,
      showTnlAuth: false,
      showSocialDivider: true,
    });
    expect(getLoginOptions({})).toEqual({
      showGoogleOAuth: false,
      showTnlAuth: false,
      showSocialDivider: false,
    });
  });

  it('shows only the tnl-auth button when it is enabled', () => {
    expect(getLoginOptions({ ...google, tnlAuthEnabled: true })).toEqual({
      showGoogleOAuth: false,
      showTnlAuth: true,
      showSocialDivider: true,
    });
  });

  it('shows tnl-auth regardless of allowedLoginMethods', () => {
    const options = getLoginOptions({
      allowedLoginMethods: ['email'],
      tnlAuthEnabled: true,
    });
    expect(options.showTnlAuth).toBe(true);
  });

  it('maps tnl-auth-failed to its message key', () => {
    expect(ERROR_MESSAGES['tnl-auth-failed']).toBe(
      'LOGIN.OAUTH.TNL_AUTH_FAILED'
    );
  });
});
