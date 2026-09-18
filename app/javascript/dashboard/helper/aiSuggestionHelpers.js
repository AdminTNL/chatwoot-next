// Accepts messages in snake_case (store) or camelCase (components).
const getSuggestionId = message =>
  message?.content_attributes?.ai_suggestion_id ??
  message?.contentAttributes?.aiSuggestionId;

const getSuggestionStatus = message =>
  message?.content_attributes?.ai_suggestion_status ??
  message?.contentAttributes?.aiSuggestionStatus;

const RESOLVED_STATUSES = ['approved', 'dismissed'];

export const hasAiSuggestion = (messages = []) =>
  (messages || []).some(message => !!getSuggestionId(message));

export const hasResolvedAiSuggestion = (messages = []) =>
  (messages || []).some(
    message =>
      !!getSuggestionId(message) &&
      RESOLVED_STATUSES.includes(getSuggestionStatus(message))
  );

export const withoutAiSuggestions = (messages = []) =>
  (messages || []).filter(message => !getSuggestionId(message));
