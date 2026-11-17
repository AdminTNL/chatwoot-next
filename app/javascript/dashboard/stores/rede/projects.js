import camelcaseKeys from 'camelcase-keys';
import ProjectsAPI from 'dashboard/api/rede/projects';
import FrontsAPI from 'dashboard/api/rede/fronts';
import { createStore } from 'dashboard/store/storeFactory';
import { throwErrorMessage } from 'dashboard/store/utils/api';

const camelize = data => camelcaseKeys(data || {}, { deep: true });

export const useRedeProjectsStore = createStore({
  name: 'rede-projects',
  type: 'pinia',
  API: ProjectsAPI,

  getters: {
    getProjects: state =>
      [...state.records].sort((a, b) => a.name.localeCompare(b.name)),
    getProjectByTeamId: state => teamId =>
      state.records.find(record => record.teamId === Number(teamId)) || {},
  },

  actions: () => ({
    // Projeto nunca é apagado, só encerrado. Sobrescreve a ação herdada do createStore.
    delete() {
      throw new Error('Projects are not deleted; use close');
    },

    upsertProject(project) {
      const index = this.records.findIndex(r => r.id === project.id);
      if (index === -1) this.records.push(project);
      else this.records[index] = project;
    },

    replaceFront(projectId, front) {
      const project = this.records.find(r => r.id === Number(projectId));
      if (!project) return;
      const fronts = project.fronts || [];
      const index = fronts.findIndex(f => f.id === front.id);
      if (index === -1) project.fronts = [...fronts, front];
      else project.fronts = fronts.map(f => (f.id === front.id ? front : f));
    },

    async get() {
      this.setUIFlag({ fetchingList: true });
      try {
        const { data } = await ProjectsAPI.get();
        this.records = camelize(data);
        return this.records;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingList: false });
      }
    },

    async create(attrs) {
      this.setUIFlag({ creatingItem: true });
      try {
        const { data } = await ProjectsAPI.create(attrs);
        const project = camelize(data);
        this.upsertProject(project);
        return project;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ creatingItem: false });
      }
    },

    async update({ id, ...attrs }) {
      this.setUIFlag({ updatingItem: true });
      try {
        const { data } = await ProjectsAPI.update(id, attrs);
        const project = camelize(data);
        this.upsertProject(project);
        return project;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ updatingItem: false });
      }
    },

    async close(id) {
      this.setUIFlag({ updatingItem: true });
      try {
        const { data } = await ProjectsAPI.close(id);
        const project = camelize(data);
        this.upsertProject(project);
        return project;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ updatingItem: false });
      }
    },

    async reopen(id) {
      this.setUIFlag({ updatingItem: true });
      try {
        const { data } = await ProjectsAPI.reopen(id);
        const project = camelize(data);
        this.upsertProject(project);
        return project;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ updatingItem: false });
      }
    },

    async createFront(projectId, attrs) {
      this.setUIFlag({ updatingItem: true });
      try {
        const { data } = await FrontsAPI.create(projectId, attrs);
        const front = camelize(data);
        this.replaceFront(projectId, front);
        return front;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ updatingItem: false });
      }
    },

    async updateFront(projectId, id, attrs) {
      this.setUIFlag({ updatingItem: true });
      try {
        const { data } = await FrontsAPI.update(projectId, id, attrs);
        const front = camelize(data);
        this.replaceFront(projectId, front);
        return front;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ updatingItem: false });
      }
    },

    async closeFront(projectId, id) {
      this.setUIFlag({ updatingItem: true });
      try {
        const { data } = await FrontsAPI.close(projectId, id);
        const front = camelize(data);
        this.replaceFront(projectId, front);
        return front;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ updatingItem: false });
      }
    },

    async reopenFront(projectId, id) {
      this.setUIFlag({ updatingItem: true });
      try {
        const { data } = await FrontsAPI.reopen(projectId, id);
        const front = camelize(data);
        this.replaceFront(projectId, front);
        return front;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ updatingItem: false });
      }
    },
  }),
});
