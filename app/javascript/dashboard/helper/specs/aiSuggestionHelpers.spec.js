import {
  hasAiSuggestion,
  hasResolvedAiSuggestion,
  withoutAiSuggestions,
} from '../aiSuggestionHelpers';

const snake = (id, status) => ({
  id,
  content_attributes: {
    ai_suggestion_id: `s${id}`,
    ai_suggestion_status: status,
  },
});
const camel = (id, status) => ({
  id,
  contentAttributes: { aiSuggestionId: `s${id}`, aiSuggestionStatus: status },
});
const plain = id => ({ id, content_attributes: {} });

describe('aiSuggestionHelpers', () => {
  describe('hasAiSuggestion', () => {
    it('returns false for empty/undefined/plain messages', () => {
      expect(hasAiSuggestion([])).toBe(false);
      expect(hasAiSuggestion(undefined)).toBe(false);
      expect(hasAiSuggestion([plain(1), { id: 2 }])).toBe(false);
    });

    it('returns true for snake or camel notes, resolved or not', () => {
      expect(hasAiSuggestion([plain(1), snake(2)])).toBe(true);
      expect(hasAiSuggestion([camel(2)])).toBe(true);
      expect(hasAiSuggestion([snake(2, 'approved')])).toBe(true);
      expect(hasAiSuggestion([camel(2, 'dismissed')])).toBe(true);
    });
  });

  describe('hasResolvedAiSuggestion', () => {
    it('returns false for empty, pending or status-less notes', () => {
      expect(hasResolvedAiSuggestion([])).toBe(false);
      expect(hasResolvedAiSuggestion(undefined)).toBe(false);
      expect(hasResolvedAiSuggestion([snake(1), camel(2, 'pending')])).toBe(
        false
      );
    });

    it('returns true for approved or dismissed notes', () => {
      expect(hasResolvedAiSuggestion([snake(1), snake(2, 'approved')])).toBe(
        true
      );
      expect(hasResolvedAiSuggestion([camel(1, 'dismissed')])).toBe(true);
    });
  });

  describe('withoutAiSuggestions', () => {
    it('removes only AI notes preserving order', () => {
      const result = withoutAiSuggestions([
        plain(1),
        snake(2),
        plain(3),
        camel(4, 'approved'),
        plain(5),
      ]);
      expect(result.map(m => m.id)).toEqual([1, 3, 5]);
    });

    it('handles empty/undefined', () => {
      expect(withoutAiSuggestions([])).toEqual([]);
      expect(withoutAiSuggestions(undefined)).toEqual([]);
    });
  });
});
