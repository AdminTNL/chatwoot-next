import conversationRoutes from '../conversation.routes';

vi.mock('../ConversationView.vue', () => ({ default: {} }));
vi.mock('dashboard/store', () => ({
  default: { getters: {}, dispatch: vi.fn() },
}));

const findRoute = name =>
  conversationRoutes.routes.find(route => route.name === name);

describe('conversation.routes - removed sidebar views', () => {
  it.each(['conversation_unattended', 'conversation_participating'])(
    '%s redirects to all conversations',
    name => {
      const route = findRoute(name);
      expect(route.component).toBeUndefined();
      expect(route.redirect({ params: { accountId: '1' } })).toEqual({
        name: 'home',
        params: { accountId: '1' },
      });
    }
  );

  it.each([
    'conversation_through_unattended',
    'conversation_through_participating',
  ])('%s redirects to the conversation in all conversations', name => {
    const route = findRoute(name);
    expect(route.component).toBeUndefined();
    expect(
      route.redirect({ params: { accountId: '1', conversationId: '42' } })
    ).toEqual({
      name: 'inbox_conversation',
      params: { accountId: '1', conversation_id: '42' },
    });
  });
});
