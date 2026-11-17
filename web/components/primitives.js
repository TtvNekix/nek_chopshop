/**
 * Shared primitives.
 *
 * <chop-ticket tone="original|canary|pink" kind="sheet|slip">
 *   The paper itself. Each view is a different copy of the same multi-part
 *   work order: the board is the white original, the tracker the canary
 *   workshop copy, the buyer the pink receipt copy. Children:
 *     .ticket__body  printed form area (perforated along its bottom edge)
 *     .ticket__stub  tear-off strip with the actions
 *   The element is presentational; all styling lives in styles/ticket.css.
 *
 * <chop-stamp label="..." slot-key="board">
 *   Red rubber stamp. It "thunks" only when its label differs from the last
 *   label shown under the same slot-key, so re-renders do not replay it.
 */

class ChopTicket extends HTMLElement {
  connectedCallback() {
    if (!this.hasAttribute('tone')) this.setAttribute('tone', 'original');
    if (!this.hasAttribute('kind')) this.setAttribute('kind', 'sheet');
  }
}

const lastStampLabel = new Map();

class ChopStamp extends HTMLElement {
  static observedAttributes = ['label'];

  connectedCallback() {
    this.#paint();
  }

  attributeChangedCallback() {
    if (this.isConnected) this.#paint();
  }

  #paint() {
    const label = this.getAttribute('label') ?? '';
    const key = this.getAttribute('slot-key') ?? '';
    this.hidden = label === '';
    this.setAttribute('role', 'img');
    this.setAttribute('aria-label', label);

    if (this.textContent !== label) this.textContent = label;

    const fresh = lastStampLabel.get(key) !== label;
    lastStampLabel.set(key, label);
    if (fresh && label) {
      this.removeAttribute('data-thunk');
      void this.offsetWidth;
      this.setAttribute('data-thunk', '');
    }
  }
}

export function definePrimitives() {
  if (!customElements.get('chop-ticket')) customElements.define('chop-ticket', ChopTicket);
  if (!customElements.get('chop-stamp')) customElements.define('chop-stamp', ChopStamp);
}
