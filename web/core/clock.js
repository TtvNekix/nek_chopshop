/**
 * One shared ticker for every countdown in the UI.
 *
 * Deadlines arrive from Lua as absolute epoch milliseconds (`expiresAt`,
 * `until`). The UI never polls Lua for time: it counts down locally against
 * `now(skew)`, where skew corrects the browser clock to the Lua clock
 * (measured from the `clock` field of every envelope, see state.js).
 *
 * The interval only runs while at least one view is listening.
 */

const TICK_MS = 250;
const listeners = new Set();
let timer = null;

export function now(skew = 0) {
  return Date.now() + skew;
}

export function onTick(listener) {
  listeners.add(listener);
  if (timer === null) {
    timer = setInterval(() => {
      for (const fn of listeners) fn();
    }, TICK_MS);
  }
  return () => {
    listeners.delete(listener);
    if (listeners.size === 0 && timer !== null) {
      clearInterval(timer);
      timer = null;
    }
  };
}
