import summaryReportsAPI from '../summaryReports';
import ApiClient from '../ApiClient';

describe('#SummaryReports API', () => {
  it('creates correct instance', () => {
    expect(summaryReportsAPI).toBeInstanceOf(ApiClient);
    expect(summaryReportsAPI.apiVersion).toBe('/api/v2');
  });

  describe('API calls', () => {
    const originalAxios = window.axios;
    const axiosMock = { get: vi.fn(() => Promise.resolve()) };

    beforeEach(() => {
      window.axios = axiosMock;
      axiosMock.get.mockClear();
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    [
      ['getTeamReports', 'team'],
      ['getAgentReports', 'agent'],
      ['getInboxReports', 'inbox'],
      ['getLabelReports', 'label'],
    ].forEach(([method, path]) => {
      const base = { since: 1, until: 2, businessHours: true };

      it(`#${method} without teamId`, () => {
        summaryReportsAPI[method](base);
        expect(axiosMock.get).toHaveBeenCalledWith(
          `/api/v2/summary_reports/${path}`,
          { params: { since: 1, until: 2, business_hours: true } }
        );
        expect(axiosMock.get.mock.calls[0][1].params.team_id).toBeUndefined();
      });

      it(`#${method} with teamId`, () => {
        summaryReportsAPI[method]({ ...base, teamId: 5 });
        expect(axiosMock.get).toHaveBeenCalledWith(
          `/api/v2/summary_reports/${path}`,
          { params: { since: 1, until: 2, business_hours: true, team_id: 5 } }
        );
      });
    });
  });
});
