import { ViewElement } from './view-element.js';
import { html } from '../core/dom.js';

/**
 * <chop-note> — a scrap of white paper torn off a pad and stuck on the right edge.
 * Used for job messages when the tracker slip is not on screen. Never takes NUI
 * focus and never receives pointer events. Lua closes it after a few seconds.
 *
 * payload = {
 *   tone: 'success' | 'inform' | 'error'   (default 'inform'),
 *   text: string,                          // already localised by Lua
 * }
 */

const TONES = new Set(['success', 'inform', 'error']);

export class LooseNote extends ViewElement {
  static view = 'note';
  static focusable = false;
  static animatedExit = true;

  template(payload, ui, { t }) {
    const tone = TONES.has(payload.tone) ? payload.tone : 'inform';

    return html`
      <chop-ticket tone="original" kind="note" role="status" aria-live="polite">
        <div class="ticket__body note__paper" data-tone="${tone}">
          <p class="note__head">${t(`note.${tone}`)}</p>
          <p class="note__text">${payload.text ?? ''}</p>
        </div>
      </chop-ticket>`;
  }
}
