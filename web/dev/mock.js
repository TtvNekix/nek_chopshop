/**
 * Dev mode: open web/index.html through any static server (ES modules do not
 * load from file://), e.g. `npx serve web` or `python -m http.server -d web`.
 *
 * - Registers the English fallback dictionary.
 * - Answers NUI callbacks (`close`, `requestJob`, `sellItem`, `answerInvite`, `ready`) locally.
 * - Plays the Lua side of the loose note (auto-close) and of the tracker notes (last 5 kept).
 * - Adds a toolbar whose buttons emit the same envelopes Lua would send,
 *   through `bridge.emit`, so every scenario exercises the real message path.
 *
 * Nothing here is imported in game: app.js loads it only when not inside CEF.
 */
import { setFallbackStrings } from '../core/i18n.js';
import english from './locale-en.js';

const minutes = (n) => n * 60_000;
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** Same values as client/interact.lua (LOG_SIZE, NOTE_MS). */
const LOG_SIZE = 5;
const NOTE_MS = 5000;
let logSeq = 0;
let mockLog = []; // kept here like Lua does: emits are async, so the store may lag behind
let noteTimer = null;

const SAMPLE_PARTS = [
  { id: 'door_dside_f', label: 'Front left door', removed: false },
  { id: 'door_pside_f', label: 'Front right door', removed: false },
  { id: 'bonnet', label: 'Hood', removed: false },
  { id: 'wheel_lf', label: 'Front left wheel', removed: false },
  { id: 'wheel_rf', label: 'Front right wheel', removed: false },
];

const SAMPLE_ITEMS = [
  { item: 'vehicle_door', label: 'Door', price: 45, owned: 4, total: 270 },
  { item: 'vehicle_hood', label: 'Hood', price: 55, owned: 1 },
  { item: 'veh_wheels', label: 'Wheel', price: 30, owned: 0 },
  { item: 'car-battery', label: 'Battery', price: 60, owned: 2 },
  { item: 'veh_suspension', label: 'Suspension', price: 70, owned: 1 },
];

/** A partial Spanish dictionary, sent through the real `init` path to show locale swaps. */
const SAMPLE_ES = {
  lang: 'es',
  currency: '$',
  strings: {
    common: { close: 'Cerrar', number: 'Nº' },
    board: {
      title: 'Desguace Sandy',
      form: 'Orden de trabajo',
      status: { label: 'Estado', available: 'Hay trabajo', cooldown: 'Próximo encargo en {time}' },
      request: 'Aceptar encargo',
    },
    stamp: { active: 'En curso', completed: 'Completado', expired: 'Caducado', cooldown: 'Espera' },
    tracker: { stage: { pickup: 'Recoger', deliver: 'Entregar', scrap: 'Desguazar' }, timeLeft: 'Tiempo', parts: 'Piezas', log: 'Anotaciones' },
    note: { inform: 'Aviso', success: 'Anotado', error: 'Error' },
    invite: { title: 'Ayudante', accept: 'Aceptar', decline: 'Rechazar' },
  },
};

function scenarios(bridge, store) {
  const emit = (message) => bridge.emit(message);
  const tracker = () => store.get().views['job-tracker'].payload;
  const logLine = (tone, text) => {
    logSeq += 1;
    mockLog = [...mockLog, { id: logSeq, at: Date.now(), tone, text }].slice(-LOG_SIZE);
    emit({ type: 'update', view: 'job-tracker', payload: { log: mockLog } });
  };
  const note = (tone, text) => {
    clearTimeout(noteTimer);
    emit({ type: 'open', view: 'note', payload: { tone, text } });
    noteTimer = setTimeout(() => emit({ type: 'close', view: 'note' }), NOTE_MS);
  };

  return [
    ['Board: available', () =>
      emit({
        type: 'open',
        view: 'job-board',
        payload: {
          ticketNo: '0412',
          status: { kind: 'available' },
          payout: { min: 100, max: 200 },
          reputation: { level: 3, xp: 340, xpMax: 500, nextUnlock: 'Engine blocks' },
        },
      })],
    ['Board: cooldown', () =>
      emit({ type: 'open', view: 'job-board', payload: { status: { kind: 'cooldown', until: Date.now() + 95_000 } } })],
    ['Board: bays full', () =>
      emit({ type: 'open', view: 'job-board', payload: { status: { kind: 'no_scrap' } } })],
    ['Tracker: start', () => {
      mockLog = [];
      emit({
        type: 'open',
        view: 'job-tracker',
        payload: {
          vehicle: { label: 'Ubermacht Sentinel', plate: 'CHOP 412' },
          stage: 'pickup',
          status: 'active',
          expiresAt: Date.now() + minutes(20),
          parts: SAMPLE_PARTS,
        },
      });
    }],
    ['Tracker: next stage', () => {
      const order = ['pickup', 'deliver', 'scrap'];
      const next = order[Math.min(order.indexOf(tracker().stage) + 1, order.length - 1)];
      emit({ type: 'update', view: 'job-tracker', payload: { stage: next, partner: next === 'scrap' ? 'M. Reyes' : undefined } });
    }],
    ['Tracker: remove part', () => {
      const parts = (tracker().parts ?? []).slice();
      const index = parts.findIndex((part) => !part.removed);
      if (index >= 0) parts[index] = { ...parts[index], removed: true };
      emit({ type: 'update', view: 'job-tracker', payload: { parts } });
    }],
    ['Tracker: 70 s left', () =>
      emit({ type: 'update', view: 'job-tracker', payload: { expiresAt: Date.now() + 70_000 } })],
    ['Tracker: completed', () =>
      emit({ type: 'update', view: 'job-tracker', payload: { status: 'completed' } })],
    ['Tracker: log line', () => logLine('success', 'Vehicle unlocked. Take it.')],
    ['Tracker: log error', () => logLine('error', 'You have no space left')],
    ['Note: notice', () => note('inform', 'M. Reyes will start the scrap soon. Wait by the vehicle.')],
    ['Note: error', () => note('error', 'You need a lockpick')],
    ['Invite', () =>
      emit({
        type: 'open',
        view: 'partner-invite',
        payload: { from: 'M. Reyes', ticketNo: 'CHOP 412', text: 'M. Reyes asks for your help scrapping a vehicle.' },
      })],
    ['Buyer', () => emit({ type: 'open', view: 'parts-buyer', payload: { items: SAMPLE_ITEMS } })],
    ['Close all', () => emit({ type: 'close' })],
    ['Locale: en', () => emit({ type: 'init', locale: { lang: 'en', currency: '$', strings: {} } })],
    ['Locale: es', () => emit({ type: 'init', locale: SAMPLE_ES })],
  ];
}

function installMocks(bridge, store) {
  bridge.mock('ready', () => ({ ok: true }));
  bridge.mock('close', () => ({ ok: true }));

  bridge.mock('requestJob', async () => {
    await wait(500);
    const status = store.get().views['job-board'].payload.status ?? {};
    const kind = status.kind === 'cooldown' && status.until <= Date.now() ? 'available' : status.kind;
    if (kind && kind !== 'available') return { ok: false, error: kind };
    setTimeout(() => {
      bridge.emit({ type: 'close', view: 'job-board' });
      bridge.emit({
        type: 'open',
        view: 'job-tracker',
        payload: {
          vehicle: { label: 'Karin Futo', plate: 'CHOP 413' },
          stage: 'pickup',
          expiresAt: Date.now() + minutes(20),
          parts: SAMPLE_PARTS,
        },
      });
    }, 900);
    return { ok: true, data: { plate: 'CHOP 413' } };
  });

  bridge.mock('answerInvite', async ({ accept }) => {
    await wait(250);
    bridge.emit({ type: 'close', view: 'partner-invite' });
    console.info(`[chopshop] dev: invite ${accept ? 'accepted' : 'declined'}`);
    return { ok: true };
  });

  bridge.mock('sellItem', async ({ item }) => {
    await wait(350);
    const row = (store.get().views['parts-buyer'].payload.items ?? []).find((entry) => entry.item === item);
    if (!row || row.owned <= 0) return { ok: false, error: 'no_item' };
    const total = Number.isFinite(row.total) ? row.total : row.owned * row.price;
    return { ok: true, data: { item, label: row.label, count: row.owned, total, owned: 0, remainingTotal: 0 } };
  });
}

function mountToolbar(bridge, store) {
  const bar = document.createElement('nav');
  bar.className = 'devbar';
  bar.setAttribute('aria-label', 'Dev scenarios');
  for (const [label, run] of scenarios(bridge, store)) {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = label;
    button.addEventListener('click', run);
    bar.append(button);
  }
  document.body.append(bar);
}

export function installDevMode({ bridge, store }) {
  setFallbackStrings(english);

  const css = document.createElement('link');
  css.rel = 'stylesheet';
  css.href = new URL('./dev.css', import.meta.url).href;
  document.head.append(css);
  document.body.classList.add('is-dev');

  installMocks(bridge, store);
  mountToolbar(bridge, store);
  console.info('[chopshop] dev mode: mocked NUI callbacks, use the toolbar to emit Lua messages.');
}
