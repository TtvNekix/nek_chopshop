import { createTranslator } from '../core/i18n.js';
import { now, onTick } from '../core/clock.js';
import { render } from '../core/dom.js';

/**
 * Base class for every view (`<chop-job-board>`, `<chop-job-tracker>`, ...).
 *
 * Pattern:
 *   - Views are light-DOM custom elements; global CSS styles them by tag.
 *   - Dependencies (store, bridge) are injected once with `ViewElement.provide()`
 *     before any element is defined; views never reach for globals.
 *   - A view renders from `(payload, ui, ctx)` only. `payload` belongs to Lua,
 *     `ui` holds local transient state (pending flags, result lines).
 *   - Clicks are delegated: any element with `data-action="x"` calls `onAction('x', el)`.
 *   - Elements with `data-focus="key"` keep keyboard focus across re-renders.
 *   - Views that show countdowns set `static ticking = true` and implement `onTick()`,
 *     updating only the nodes that change (no full re-render every second).
 *
 * Subclasses provide: `static view`, `template(payload, ui, ctx)`, and optionally
 * `onAction()`, `onTick()`, `static focusable` (menus that take NUI focus).
 */
export class ViewElement extends HTMLElement {
  static view = '';
  static focusable = true;
  static ticking = false;
  /** Views with an exit motion in CSS (`[data-leave]`) stay visible until it finishes. */
  static animatedExit = false;
  static #deps = null;

  static provide(deps) {
    ViewElement.#deps = deps;
  }

  get deps() {
    return ViewElement.#deps;
  }

  get viewId() {
    return this.constructor.view;
  }

  connectedCallback() {
    this.hidden = true;
    this.dataset.view = this.viewId;
    this.addEventListener('click', this.#handleClick);
    this.addEventListener('animationend', this.#handleEntered);
    this.#unsubscribe = this.deps.store.subscribe((next, prev) => this.#sync(next, prev));
    this.#sync(this.deps.store.get(), null);
  }

  disconnectedCallback() {
    this.removeEventListener('click', this.#handleClick);
    this.removeEventListener('animationend', this.#handleEntered);
    this.#unsubscribe?.();
    this.#stopTicking();
  }

  /** Current view slice plus helpers every template needs. */
  get ctx() {
    const state = this.deps.store.get();
    return {
      t: createTranslator(state.locale),
      locale: state.locale,
      now: () => now(state.clockSkew),
      seq: state.views[this.viewId].seq,
    };
  }

  get slice() {
    return this.deps.store.get().views[this.viewId];
  }

  /** Local UI state helpers. */
  setUi(ui) {
    this.deps.store.dispatch({ type: 'ui/set', view: this.viewId, ui });
  }

  patchPayload(payload) {
    this.deps.store.dispatch({ type: 'ui/payload', view: this.viewId, payload });
  }

  /** Close locally right away and tell Lua, so focus is never stuck on a dead UI. */
  requestClose() {
    this.deps.store.dispatch({ type: 'close', view: this.viewId });
    this.deps.bridge.post('close', { view: this.viewId });
  }

  ref(name) {
    return this.querySelector(`[data-ref="${name}"]`);
  }

  /** Overridables. */
  template() {
    return '';
  }

  onAction() {}

  onTick() {}

  rerender() {
    const slice = this.slice;
    if (!slice.open) return;
    const focusKey = this.contains(document.activeElement) ? document.activeElement.dataset.focus : null;
    render(this, this.template(slice.payload, slice.ui, this.ctx));
    if (focusKey) this.querySelector(`[data-focus="${focusKey}"]`)?.focus({ preventScroll: true });
    if (this.constructor.ticking) this.onTick(this.ctx);
  }

  // ---- internals ---------------------------------------------------------

  #unsubscribe = null;
  #stopTick = null;
  #leave = null;

  #handleClick = (event) => {
    const target = event.target.closest('[data-action]');
    if (!target || !this.contains(target) || target.disabled) return;
    this.onAction(target.dataset.action, target);
  };

  // Entry motion plays once per open; later re-renders rebuild the ticket and must not replay it.
  #handleEntered = (event) => {
    if (event.target.localName === 'chop-ticket') this.removeAttribute('data-enter');
  };

  #sync(next, prev) {
    const slice = next.views[this.viewId];
    const before = prev?.views[this.viewId];
    const localeChanged = !prev || prev.locale !== next.locale;

    if (!slice.open) {
      if (before?.open) this.#hide();
      return;
    }

    const opened = !before?.open || before.seq !== slice.seq;
    if (opened || localeChanged || before.payload !== slice.payload || before.ui !== slice.ui) {
      this.rerender();
    }
    if (opened) this.#show();
  }

  #show() {
    this.#cancelLeave();
    this.hidden = false;
    // Restart the entry animation on every open, including re-opens.
    this.removeAttribute('data-enter');
    void this.offsetWidth;
    this.setAttribute('data-enter', '');
    if (this.constructor.ticking) this.#startTicking();
    if (this.constructor.focusable) {
      const first = this.querySelector('[data-autofocus]:not([disabled])') ?? this.querySelector('button:not([disabled])');
      first?.focus({ preventScroll: true });
    }
  }

  #hide() {
    this.#stopTicking();
    if (!this.constructor.animatedExit || this.hidden) {
      this.#finishHide();
      return;
    }
    // Play the exit motion (`[data-leave]` in CSS), then hide. A re-open while leaving cancels it;
    // the timeout covers a missing animationend (e.g. the view was never painted).
    this.#cancelLeave();
    this.removeAttribute('data-enter');
    this.setAttribute('data-leave', '');
    const done = (event) => {
      if (event && event.target.localName !== 'chop-ticket') return;
      this.#cancelLeave();
      this.#finishHide();
    };
    this.addEventListener('animationend', done);
    const timer = setTimeout(done, 900);
    this.#leave = () => {
      this.removeEventListener('animationend', done);
      clearTimeout(timer);
      this.removeAttribute('data-leave');
    };
  }

  #finishHide() {
    this.hidden = true;
    this.replaceChildren();
  }

  #cancelLeave() {
    this.#leave?.();
    this.#leave = null;
  }

  #startTicking() {
    if (this.#stopTick) return;
    this.#stopTick = onTick(() => this.onTick(this.ctx));
  }

  #stopTicking() {
    this.#stopTick?.();
    this.#stopTick = null;
  }
}
