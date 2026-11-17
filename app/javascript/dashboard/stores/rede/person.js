import camelcaseKeys from 'camelcase-keys';
import PeopleAPI from 'dashboard/api/rede/people';
import EvaluationsAPI from 'dashboard/api/rede/evaluations';
import InteractionsAPI from 'dashboard/api/rede/interactions';
import AssignmentsAPI from 'dashboard/api/rede/assignments';
import ParticipationsAPI from 'dashboard/api/rede/participations';
import { createStore } from 'dashboard/store/storeFactory';
import { throwErrorMessage } from 'dashboard/store/utils/api';

const ATTRIBUTE_PATHS = [
  'contact.custom_attributes',
  'contact.additional_attributes',
];

const camelize = data =>
  camelcaseKeys(data || {}, { deep: true, stopPaths: ATTRIBUTE_PATHS });

// Chave estável de um evento do histórico, para não duplicar entre páginas.
// Atuação iniciada e encerrada compartilham o id da atuação, por isso entra a ação.
export const timelineEventKey = event => {
  const { data = {} } = event;
  const id =
    data.conversationId ??
    data.interactionId ??
    data.evaluationId ??
    data.assignmentId;
  return [event.type, data.action, id, event.occurredAt].join(':');
};

const compact = data =>
  Object.fromEntries(
    Object.entries(data).filter(([, value]) => value !== undefined)
  );

export const useRedePersonStore = createStore({
  name: 'rede-person',
  type: 'pinia',
  API: PeopleAPI,
  state: () => ({
    person: {},
    timeline: [],
    timelineMeta: {},
    timelineParams: {},
    notFound: false,
  }),

  actions: () => ({
    async show(id) {
      this.setUIFlag({ fetchingItem: true });
      try {
        const { data } = await PeopleAPI.show(id);
        this.person = camelize(data);
        this.notFound = false;
        return this.person;
      } catch (error) {
        // 404: pessoa inexistente ou fora do escopo. A tela mostra o aviso.
        if (error?.response?.status === 404) {
          this.person = {};
          this.notFound = true;
          return null;
        }
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingItem: false });
      }
    },

    async fetchTimeline(id, params) {
      const {
        data: { payload, meta },
      } = await PeopleAPI.timeline(id, params);
      return {
        events: camelcaseKeys(payload || [], { deep: true }),
        meta: camelcaseKeys(meta || {}),
      };
    },

    async getTimeline(id, params = {}) {
      this.setUIFlag({ fetchingTimeline: true });
      try {
        const { events, meta } = await this.fetchTimeline(id, params);
        this.timeline = events;
        this.timelineMeta = meta;
        this.timelineParams = params;
        return events;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingTimeline: false });
      }
    },

    async loadMoreTimeline(id, params = this.timelineParams) {
      const before = this.timelineMeta?.nextCursor;
      if (!before) return [];
      this.setUIFlag({ fetchingTimeline: true });
      try {
        const { events, meta } = await this.fetchTimeline(id, {
          ...params,
          before,
        });
        const seen = new Set(this.timeline.map(timelineEventKey));
        const fresh = events.filter(
          event => !seen.has(timelineEventKey(event))
        );
        this.timeline = [...this.timeline, ...fresh];
        this.timelineMeta = meta;
        return events;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ fetchingTimeline: false });
      }
    },

    // Roda a mutação e, se der certo, recarrega a ficha e o histórico.
    async runAction(contactId, request) {
      this.setUIFlag({ savingAction: true });
      try {
        const { data } = await request();
        try {
          await Promise.all([
            this.show(contactId),
            this.getTimeline(contactId, this.timelineParams),
          ]);
        } catch (refreshError) {
          // A ação já foi salva: falha ao recarregar não pode parecer falha da ação.
        }
        return camelcaseKeys(data || {}, { deep: true });
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        this.setUIFlag({ savingAction: false });
      }
    },

    setTemperature({ projectId, contactId, frontId, level, note }) {
      return this.runAction(contactId, () =>
        EvaluationsAPI.create({
          project_id: projectId,
          contact_id: contactId,
          front_id: frontId,
          level,
          note,
        })
      );
    },

    createInteraction(kind, attrs) {
      const { projectId, contactId, frontId, answered, summary, occurredAt } =
        attrs;
      return this.runAction(contactId, () =>
        InteractionsAPI.create({
          project_id: projectId,
          contact_id: contactId,
          front_id: frontId,
          kind,
          answered,
          summary,
          occurred_at: occurredAt,
        })
      );
    },

    updateInteraction({ contactId, id, summary, answered }) {
      const data = compact({ summary, answered });
      return this.runAction(contactId, () => InteractionsAPI.update(id, data));
    },

    logCall(attrs) {
      return this.createInteraction('call', attrs);
    },

    addNote(attrs) {
      return this.createInteraction('note', attrs);
    },

    createAssignment({
      contactId,
      participationId,
      frontId,
      roleId,
      superiorContactId,
    }) {
      return this.runAction(contactId, () =>
        AssignmentsAPI.create(participationId, {
          front_id: frontId,
          role_id: roleId,
          superior_contact_id: superiorContactId,
        })
      );
    },

    updateAssignment({
      contactId,
      participationId,
      id,
      frontId,
      roleId,
      superiorContactId,
    }) {
      const data = compact({
        front_id: frontId,
        role_id: roleId,
        superior_contact_id: superiorContactId,
      });
      return this.runAction(contactId, () =>
        AssignmentsAPI.update(participationId, id, data)
      );
    },

    closeAssignment({ contactId, participationId, id }) {
      return this.runAction(contactId, () =>
        AssignmentsAPI.close(participationId, id)
      );
    },

    createParticipation({ projectId, contactId, assignment }) {
      return this.runAction(contactId, () =>
        ParticipationsAPI.create({
          project_id: projectId,
          contact_id: contactId,
          assignment,
        })
      );
    },

    updateParticipation({
      contactId,
      id,
      responsibleUserId,
      nextStep,
      referredByContactId,
      referredByText,
      status,
    }) {
      const data = compact({
        responsible_user_id: responsibleUserId,
        next_step: nextStep,
        referred_by_contact_id: referredByContactId,
        referred_by_text: referredByText,
        status,
      });
      return this.runAction(contactId, () =>
        ParticipationsAPI.update(id, data)
      );
    },

    reset() {
      this.person = {};
      this.timeline = [];
      this.timelineMeta = {};
      this.timelineParams = {};
      this.notFound = false;
      this.uiFlags = {
        ...this.uiFlags,
        fetchingItem: false,
        fetchingTimeline: false,
        savingAction: false,
      };
    },
  }),
});
