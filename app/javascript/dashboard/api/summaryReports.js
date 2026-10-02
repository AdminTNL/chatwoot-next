/* global axios */
import ApiClient from './ApiClient';

class SummaryReportsAPI extends ApiClient {
  constructor() {
    super('summary_reports', { accountScoped: true, apiVersion: 'v2' });
  }

  getTeamReports({ since, until, businessHours, teamId } = {}) {
    return axios.get(`${this.url}/team`, {
      params: {
        since,
        until,
        business_hours: businessHours,
        team_id: teamId,
      },
    });
  }

  getAgentReports({ since, until, businessHours, teamId } = {}) {
    return axios.get(`${this.url}/agent`, {
      params: {
        since,
        until,
        business_hours: businessHours,
        team_id: teamId,
      },
    });
  }

  getInboxReports({ since, until, businessHours, teamId } = {}) {
    return axios.get(`${this.url}/inbox`, {
      params: {
        since,
        until,
        business_hours: businessHours,
        team_id: teamId,
      },
    });
  }

  getLabelReports({ since, until, businessHours, teamId } = {}) {
    return axios.get(`${this.url}/label`, {
      params: {
        since,
        until,
        business_hours: businessHours,
        team_id: teamId,
      },
    });
  }
}

export default new SummaryReportsAPI();
