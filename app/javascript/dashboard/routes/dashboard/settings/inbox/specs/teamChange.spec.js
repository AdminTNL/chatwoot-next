import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { hasTeamChanged } from '../helpers/teamChange';
import TeamChangeConfirmDialog from '../components/TeamChangeConfirmDialog.vue';
import Settings from '../Settings.vue';

describe('hasTeamChanged', () => {
  it('ignora diferenças de tipo e vazio', () => {
    expect(hasTeamChanged(5, '5')).toBe(false);
    expect(hasTeamChanged(null, '')).toBe(false);
    expect(hasTeamChanged(undefined, '')).toBe(false);
  });

  it('detecta troca de time', () => {
    expect(hasTeamChanged(null, 3)).toBe(true);
    expect(hasTeamChanged(3, '')).toBe(true);
    expect(hasTeamChanged(3, 4)).toBe(true);
  });
});

describe('TeamChangeConfirmDialog', () => {
  const i18n = createI18n({
    legacy: false,
    locale: 'en',
    missingWarn: false,
    fallbackWarn: false,
    messages: {
      en: {
        INBOX_MGMT: {
          SETTINGS_POPUP: {
            RESPONSIBLE_TEAM: {
              CHANGE_CONFIRM: {
                TITLE: 'Move to {teamName}?',
                TITLE_NO_TEAM: 'Remove team?',
              },
            },
          },
        },
      },
    },
  });

  const DialogStub = {
    name: 'Dialog',
    props: ['title'],
    emits: ['confirm', 'close'],
    template: '<div><h3>{{ title }}</h3><slot name="description" /></div>',
    methods: {
      open() {},
      close() {
        this.$emit('close');
      },
    },
  };

  const build = props =>
    mount(TeamChangeConfirmDialog, {
      props,
      global: { plugins: [i18n], stubs: { Dialog: DialogStub } },
    });

  it('renderiza o título com o nome do time', () => {
    expect(build({ teamName: 'Suporte' }).text()).toContain('Move to Suporte?');
  });

  it('renderiza a variante sem time', () => {
    expect(build({ teamName: '' }).text()).toContain('Remove team?');
  });

  it('emite confirm sem emitir cancel', async () => {
    const wrapper = build({ teamName: 'Suporte' });
    wrapper.vm.open();
    await wrapper.findComponent(DialogStub).vm.$emit('confirm');
    expect(wrapper.emitted('confirm')).toHaveLength(1);
    expect(wrapper.emitted('cancel')).toBeUndefined();
  });

  it('emite cancel ao fechar sem confirmar', async () => {
    const wrapper = build({ teamName: 'Suporte' });
    wrapper.vm.open();
    await wrapper.findComponent(DialogStub).vm.$emit('close');
    expect(wrapper.emitted('cancel')).toHaveLength(1);
    expect(wrapper.emitted('confirm')).toBeUndefined();
  });
});

describe('Settings updateInbox com troca de time', () => {
  const build = (teamId, selectedTeamId) => ({
    inbox: { team_id: teamId },
    selectedTeamId,
    saveInbox: vi.fn(),
    $refs: { teamChangeConfirmDialog: { open: vi.fn() } },
  });

  it('salva direto quando o time não mudou', () => {
    const ctx = build(5, '5');
    Settings.methods.updateInbox.call(ctx);
    expect(ctx.saveInbox).toHaveBeenCalled();
    expect(ctx.$refs.teamChangeConfirmDialog.open).not.toHaveBeenCalled();
  });

  it('abre o modal e não salva quando o time mudou', () => {
    const ctx = build(5, 6);
    Settings.methods.updateInbox.call(ctx);
    expect(ctx.$refs.teamChangeConfirmDialog.open).toHaveBeenCalled();
    expect(ctx.saveInbox).not.toHaveBeenCalled();
  });

  it('cancelar restaura o seletor', () => {
    const ctx = build(5, 6);
    Settings.methods.cancelTeamChange.call(ctx);
    expect(ctx.selectedTeamId).toBe(5);
    const sem = build(null, 6);
    Settings.methods.cancelTeamChange.call(sem);
    expect(sem.selectedTeamId).toBe('');
  });
});
