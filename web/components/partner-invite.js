import { ViewElement } from './view-element.js';
import { html } from '../core/dom.js';

/**
 * <chop-partner-invite> — white work order asking this player to help strip a vehicle.
 * Takes NUI focus. Accept / Decline post `answerInvite`; Escape (or Lua closing it,
 * e.g. on its 30 s timeout) counts as a decline on the Lua side.
 *
 * payload = {
 *   from?:     string,   // who is asking
 *   text:      string,   // the handwritten request, already localised by Lua
 *   ticketNo?: string,   // printed in red top right (the job plate)
 * }
 */

export class PartnerInvite extends ViewElement {
  static view = 'partner-invite';
  static focusable = true;

  template(payload, ui, { t }) {
    return html`
      <chop-ticket tone="original" kind="sheet" role="alertdialog" aria-modal="true"
        aria-labelledby="invite-title" aria-describedby="invite-text">
        <div class="ticket__body ruled">
          <header class="ticket__head">
            <h1 class="ticket__title" id="invite-title">${t('invite.title')}</h1>
            <p class="ticket__form">${t('board.form')}</p>
            ${payload.ticketNo && html`<p class="ticket__no">${t('common.number')} <b class="num">${payload.ticketNo}</b></p>`}
          </header>

          <p class="invite__text" id="invite-text">${payload.text ?? ''}</p>
        </div>

        <div class="ticket__stub">
          <button type="button" class="btn btn--ink" data-action="accept" data-focus="accept"
            aria-busy="${ui.pending === 'accept' ? 'true' : 'false'}" ${ui.pending ? 'disabled' : ''}>${t('invite.accept')}</button>
          <button type="button" class="btn btn--outline" data-action="decline" data-focus="decline" data-autofocus
            aria-busy="${ui.pending === 'decline' ? 'true' : 'false'}" ${ui.pending ? 'disabled' : ''}>
            ${t('invite.decline')} <kbd>Esc</kbd>
          </button>
        </div>
      </chop-ticket>`;
  }

  async onAction(action) {
    if ((action !== 'accept' && action !== 'decline') || this.slice.ui.pending) return;

    const openedSeq = this.slice.seq;
    this.setUi({ pending: action });
    const reply = await this.deps.bridge.post('answerInvite', { accept: action === 'accept' });
    if (!this.slice.open || this.slice.seq !== openedSeq) return;

    // On success Lua closes the sheet. Anything else (expired, transport): close it here,
    // which Lua also reads as a decline, so focus is never left on a dead invite.
    if (!reply.ok) this.requestClose();
  }
}
