/**
 * Bridge: the single doorway between Lua and the UI.
 *
 *   Lua -> NUI   SendNUIMessage(envelope)   ->  window 'message'  ->  onMessage(fn)
 *   NUI -> Lua   post(action, data)         ->  fetch https://<resource>/<action>
 *
 * Nothing else in the UI touches `window.addEventListener('message')` or `fetch`.
 * Every post resolves (never rejects) to the reply shape `{ ok, data?, error? }`,
 * so callers handle one code path. See CONTRACT.md for the message catalogue.
 *
 * Outside FiveM's CEF (`GetParentResourceName` missing) the bridge runs in dev
 * mode: posts are answered by handlers registered with `mock()`, and `emit()`
 * simulates a Lua message through the exact same window 'message' path.
 */

export const CONTRACT_VERSION = 1;

const REPLY_TIMEOUT_MS = 10_000;

function normalizeReply(reply) {
  if (reply && typeof reply === 'object' && typeof reply.ok === 'boolean') {
    return reply.ok
      ? { ok: true, data: reply.data ?? null }
      : { ok: false, error: typeof reply.error === 'string' ? reply.error : 'failed' };
  }
  return { ok: false, error: 'bad_reply' };
}

function isEnvelope(value) {
  return value !== null && typeof value === 'object' && typeof value.type === 'string';
}

export function createBridge() {
  const inGame = typeof window.GetParentResourceName === 'function';
  const resource = inGame ? window.GetParentResourceName() : 'nek_chopshop';
  const listeners = new Set();
  const mocks = new Map();

  window.addEventListener('message', (event) => {
    const message = event.data;
    if (!isEnvelope(message)) return;
    if (message.v !== undefined && message.v !== CONTRACT_VERSION) {
      console.warn(`[bridge] contract v${message.v} received, UI speaks v${CONTRACT_VERSION}`);
    }
    const stamped = { ...message, receivedAt: Date.now() };
    for (const listener of listeners) listener(stamped);
  });

  async function postToLua(action, data) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), REPLY_TIMEOUT_MS);
    try {
      const response = await fetch(`https://${resource}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
        signal: controller.signal,
      });
      return normalizeReply(await response.json().catch(() => null));
    } catch (err) {
      return { ok: false, error: err?.name === 'AbortError' ? 'timeout' : 'transport' };
    } finally {
      clearTimeout(timer);
    }
  }

  async function postToMock(action, data) {
    const handler = mocks.get(action);
    if (!handler) return { ok: false, error: 'no_handler' };
    try {
      return normalizeReply(await handler(data));
    } catch (err) {
      console.error(`[bridge:dev] mock '${action}' threw`, err);
      return { ok: false, error: 'internal' };
    }
  }

  return {
    inGame,
    resource,

    /** Subscribe to Lua messages. Returns an unsubscribe function. */
    onMessage(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },

    /** Call a Lua NUI callback. Always resolves to `{ ok, data?, error? }`. */
    post(action, data = {}) {
      return inGame ? postToLua(action, data) : postToMock(action, data);
    },

    /** Dev only: answer `post(action)` locally. */
    mock(action, handler) {
      mocks.set(action, handler);
    },

    /** Dev only: deliver a message as if Lua had sent it. */
    emit(message) {
      window.postMessage({ v: CONTRACT_VERSION, clock: Date.now(), ...message }, '*');
    },
  };
}
