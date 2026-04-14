export const FERRY_ROUTE_COLORS: Record<string, string> = {
  ER: '#228B9D',
  SBK: '#FFD100',
  AST: '#FE5000',
  RWS: '#4E008E',
  STG: '#D0006F',
  GOV: '#9893A0',
}

export const MAP_CENTER: [number, number] = [-74.003, 40.6850]
export const MAP_DEFAULT_ZOOM = 10.5
export const CARTO_DARK_STYLE = 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json'

export const FERRY_ROUTES = ['ER', 'SBK', 'AST', 'RWS', 'STG', 'GOV'] as const
export type FerryRoute = (typeof FERRY_ROUTES)[number]

export const PLACEHOLDER_STOPS: Record<string, [number, number]> = {
  'Hunters Point South': [-73.9573, 40.7437],
  'Wall St/Pier 11': [-74.009, 40.7028],
  'East 34th St': [-73.9727, 40.7447],
  'Atlantic Basin': [-74.0168, 40.6831],
  'Pier 11/Wall St': [-74.009, 40.7028],
  'Bay Ridge': [-74.0318, 40.6269],
  'Soundview': [-73.8738, 40.8121],
}
