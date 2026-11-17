/**
 * Bootstrap. Wiring only, no view logic:
 *
 *   bridge (Lua messages) ──dispatch──▶ store ──subscribe──▶ views
 *   views ──bridge.post(action)──▶ Lua ──reply { ok, data, error }──▶ views
 *
 * In dev mode (plain browser) the mock module is loaded dynamically, so it
 * never ships work to the game client.
 */
import { CONTRACT_VERSION, createBridge } from './core/bridge.js';
import { createStore } from './core/store.js';
import { initialState, reducer } from './core/state.js';
import { registerComponents, VIEW_TAGS } from './components/index.js';

const LUA_MESSAGES = new Set(['init', 'open', 'update', 'close']);

async function boot() {
  const bridge = createBridge();
  const store = createStore(reducer, initialState);

  bridge.onMessage((message) => {
    if (LUA_MESSAGES.has(message.type)) store.dispatch(message);
  });

  registerComponents({ store, bridge });

  const stage = document.getElementById('stage');
  for (const [tag] of Object.values(VIEW_TAGS)) stage.append(document.createElement(tag));

  document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    // Only menus close on Escape; the tracker has no focus and stays put.
    const menu = [...stage.children].find((el) => !el.hidden && el.constructor.focusable);
    menu?.requestClose();
  });

  if (!bridge.inGame) {
    const { installDevMode } = await import('./dev/mock.js');
    installDevMode({ bridge, store });
  }

  // Tells Lua the page is listening; Lua flushes queued messages after this.
  bridge.post('ready', { v: CONTRACT_VERSION });
}

boot();
