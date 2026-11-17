import { paramsToQuery, queryToParams } from '../peopleQuery';

describe('peopleQuery', () => {
  const params = {
    project_ids: [1, 2],
    temperatures: ['none'],
    no_contact_days: 7,
    page: 2,
  };
  const query = {
    project_ids: '1,2',
    temperatures: 'none',
    no_contact_days: '7',
    page: '2',
  };

  it('converts params to a query', () => {
    expect(paramsToQuery(params)).toEqual(query);
  });

  it('converts a query back to params', () => {
    expect(queryToParams(query)).toEqual(params);
  });

  it('round trips all supported params', () => {
    const full = {
      q: 'ana',
      city: 'Recife',
      project_ids: [3],
      front_ids: [4, 5],
      responsible_ids: [6],
      temperatures: ['vapor', 'quente', 'morno', 'frio', 'none'],
      no_contact_days: 30,
      has_front: true,
      front_pending: true,
      include_closed: true,
      sort: '-name',
      page: 3,
      per_page: 50,
    };
    expect(queryToParams(paramsToQuery(full))).toEqual(full);
  });

  it('omits empty arrays, empty strings and nullish values', () => {
    expect(
      paramsToQuery({
        project_ids: [],
        temperatures: [],
        q: '  ',
        city: '',
        page: null,
        no_contact_days: undefined,
        has_front: false,
      })
    ).toEqual({});
  });

  it('ignores invalid values coming from the URL', () => {
    expect(
      queryToParams({
        project_ids: '1,abc,-2,0,3',
        front_ids: ',,',
        temperatures: 'quente,ardendo,none',
        no_contact_days: 'x',
        page: '0',
        per_page: '-1',
        has_front: 'maybe',
        include_closed: 'false',
        sort: 'evil',
        unknown: '1',
      })
    ).toEqual({ project_ids: [1, 3], temperatures: ['quente', 'none'] });
  });

  it('accepts a repeated query key as an array', () => {
    expect(queryToParams({ project_ids: ['1', '2,3'] })).toEqual({
      project_ids: [1, 2, 3],
    });
  });

  it('keeps the none option of the front and responsible filters', () => {
    const withNone = { front_ids: [4, 'none'], responsible_ids: ['none'] };
    expect(paramsToQuery(withNone)).toEqual({
      front_ids: '4,none',
      responsible_ids: 'none',
    });
    expect(queryToParams(paramsToQuery(withNone))).toEqual(withNone);
    expect(queryToParams({ project_ids: 'none' })).toEqual({});
  });

  it('handles an empty query', () => {
    expect(queryToParams()).toEqual({});
    expect(queryToParams({})).toEqual({});
  });
});
