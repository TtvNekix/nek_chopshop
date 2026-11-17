/**
 * Tiny observable store.
 *
 * State only changes through `dispatch(action)`, which runs a pure reducer.
 * Subscribers receive `(next, prev)` and decide what changed by reference
 * comparison, so the reducer must return new objects for changed branches
 * and the same objects for untouched ones.
 */
export function createStore(reducer, initialState) {
  let state = initialState;
  const subscribers = new Set();

  return {
    get() {
      return state;
    },

    dispatch(action) {
      const prev = state;
      const next = reducer(prev, action);
      if (next === prev) return;
      state = next;
      for (const subscriber of subscribers) subscriber(next, prev);
    },

    subscribe(subscriber) {
      subscribers.add(subscriber);
      return () => subscribers.delete(subscriber);
    },
  };
}
