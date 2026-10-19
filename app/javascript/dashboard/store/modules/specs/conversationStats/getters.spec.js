import { getters } from '../../conversationStats';

describe('#getters', () => {
  it('getCurrentPage', () => {
    const state = {
      allCount: 2,
    };
    expect(getters.getStats(state)).toEqual({
      allCount: 2,
    });
  });
});
