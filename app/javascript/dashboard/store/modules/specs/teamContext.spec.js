import teamContext, { SET_SELECTED_TEAM_ID } from '../teamContext';

const { state, getters, actions, mutations } = teamContext;

describe('#teamContext', () => {
  it('starts with null selectedTeamId', () => {
    expect(state.selectedTeamId).toBeNull();
    expect(getters.getSelectedTeamId({ selectedTeamId: null })).toBeNull();
  });

  describe('#setSelectedTeam', () => {
    it.each([
      [5, 5],
      ['5', 5],
      [0, null],
      [null, null],
      ['', null],
      [undefined, null],
      ['abc', null],
    ])('setSelectedTeam(%j) commits %j', (input, expected) => {
      const commit = vi.fn();
      actions.setSelectedTeam({ commit }, input);
      expect(commit).toHaveBeenCalledWith(SET_SELECTED_TEAM_ID, expected);
    });
  });

  it('#clearSelectedTeam commits null', () => {
    const commit = vi.fn();
    actions.clearSelectedTeam({ commit });
    expect(commit).toHaveBeenCalledWith(SET_SELECTED_TEAM_ID, null);
  });

  it('mutation updates state and getter reflects it', () => {
    const $state = { selectedTeamId: null };
    mutations[SET_SELECTED_TEAM_ID]($state, 7);
    expect(getters.getSelectedTeamId($state)).toBe(7);
    mutations[SET_SELECTED_TEAM_ID]($state, null);
    expect(getters.getSelectedTeamId($state)).toBeNull();
  });
});
