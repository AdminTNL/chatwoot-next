import { shallowMount } from '@vue/test-utils';
import TnlAuthButton from './Button.vue';

function getWrapper() {
  return shallowMount(TnlAuthButton);
}

describe('TnlAuthButton.vue', () => {
  afterEach(() => {
    window.chatwootConfig = {};
  });

  it('links to the server-side login start endpoint', () => {
    window.chatwootConfig = { tnlAuthProvider: 'google' };
    const wrapper = getWrapper();
    expect(wrapper.find('a').attributes('href')).toBe('/tnl_auth/login');
  });

  it('shows the Google label and icon when the provider is google', () => {
    window.chatwootConfig = { tnlAuthProvider: 'google' };
    const wrapper = getWrapper();
    expect(wrapper.text()).toContain('Login with Google');
    expect(wrapper.find('.i-logos-google-icon').exists()).toBe(true);
    expect(wrapper.find('.i-lucide-log-in').exists()).toBe(false);
  });

  it('shows the generic label and icon when the provider is empty', () => {
    window.chatwootConfig = { tnlAuthProvider: '' };
    const wrapper = getWrapper();
    expect(wrapper.text()).toContain('Login with your Tiro na Lua account');
    expect(wrapper.text()).not.toContain('Login with Google');
    expect(wrapper.find('.i-lucide-log-in').exists()).toBe(true);
    expect(wrapper.find('.i-logos-google-icon').exists()).toBe(false);
  });
});
