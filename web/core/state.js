/**
 * Application state shape and the reducer that applies both Lua messages
 * (`init`, `open`, `update`, `close`) and local UI actions (`ui/*`).
 *
 * state = {
 *   locale:    { lang, currency, strings },        // from `init`
 *   clockSkew: number,                             // Lua clock - browser clock (ms)
 *   views: {
 *     [viewId]: {
 *       open:    boolean,
 *       seq:     number,   // increments on every `open`, lets views replay entry motion
 *       payload: object,   // owned by Lua: replaced on `open`, shallow-merged on `update`
 *       ui:      object,   // owned by the UI: pending flags, result lines
 *     }
 *   }
 * }
 */

export const VIEWS = Object.freeze(['job-board', 'job-tracker', 'parts-buyer']);

const emptyView = Object.freeze({ open: false, seq: 0, payload: {}, ui: {} });

export const initialState = Object.freeze({
  locale: { lang: 'en', currency: '$', strings: {} },
  clockSkew: 0,
  views: Object.fromEntries(VIEWS.map((id) => [id, emptyView])),
});

/** Flattens nested locale objects into dotted keys: { a: { b: 'x' } } -> { 'a.b': 'x' }. */
export function flattenStrings(source, prefix = '', out = {}) {
  if (!source || typeof source !== 'object') return out;
  for (const [key, value] of Object.entries(source)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (value !== null && typeof value === 'object') flattenStrings(value, path, out);
    else if (value !== undefined && value !== null) out[path] = String(value);
  }
  return out;
}

function normalizeLocale(raw) {
  if (!raw || typeof raw !== 'object') return initialState.locale;
  const hasEnvelope = raw.strings && typeof raw.strings === 'object';
  return {
    lang: typeof raw.lang === 'string' ? raw.lang : 'en',
    currency: typeof raw.currency === 'string' ? raw.currency : '$',
    strings: flattenStrings(hasEnvelope ? raw.strings : raw),
  };
}

function withView(state, id, change) {
  const current = state.views[id];
  if (!current) {
    console.warn(`[state] unknown view '${id}'`);
    return state;
  }
  const next = change(current);
  if (next === current) return state;
  return { ...state, views: { ...state.views, [id]: next } };
}

function asObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function syncClock(state, action) {
  if (typeof action.clock !== 'number' || typeof action.receivedAt !== 'number') return state;
  const skew = action.clock - action.receivedAt;
  // Ignore jitter below one second; Lua clock resolution is one second anyway.
  return Math.abs(skew - state.clockSkew) < 1000 ? state : { ...state, clockSkew: skew };
}

export function reducer(state, action) {
  switch (action.type) {
    case 'init':
      return { ...syncClock(state, action), locale: normalizeLocale(action.locale) };

    case 'open':
      return withView(syncClock(state, action), action.view, (view) => ({
        open: true,
        seq: view.seq + 1,
        payload: asObject(action.payload),
        ui: {},
      }));

    case 'update':
      return withView(syncClock(state, action), action.view, (view) =>
        view.open ? { ...view, payload: { ...view.payload, ...asObject(action.payload) } } : view,
      );

    case 'close': {
      const targets = action.view ? [action.view] : VIEWS;
      return targets.reduce(
        (acc, id) => withView(acc, id, (view) => (view.open ? { ...view, open: false } : view)),
        state,
      );
    }

    case 'ui/set':
      return withView(state, action.view, (view) => ({ ...view, ui: { ...view.ui, ...action.ui } }));

    case 'ui/payload':
      return withView(state, action.view, (view) => ({
        ...view,
        payload: { ...view.payload, ...asObject(action.payload) },
      }));

    default:
      return state;
  }
}
