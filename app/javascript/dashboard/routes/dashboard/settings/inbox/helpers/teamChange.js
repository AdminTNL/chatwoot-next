const normalizeTeamId = teamId => {
  if (teamId === null || teamId === undefined || teamId === '') return null;
  const number = Number(teamId);
  return Number.isNaN(number) ? null : number;
};

export const hasTeamChanged = (currentTeamId, selectedTeamId) =>
  normalizeTeamId(currentTeamId) !== normalizeTeamId(selectedTeamId);
