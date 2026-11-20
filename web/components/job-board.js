import { ViewElement } from './view-element.js';
import { html } from '../core/dom.js';
import { errorText, formatDuration, formatMoney } from '../core/i18n.js';

/**
 * <chop-job-board> — the work order handed out at the job ped.
 *
 * payload = {
 *   shopName?:   string,
 *   ticketNo?:   string,
 *   status:      { kind: 'available' | 'cooldown' | 'no_police' | 'no_scrap' | 'busy', until?: epochMs },
 *   payout?:     { min: number, max: number },
 *   reputation?: { level: number, xp: number, xpMax: number, nextUnlock?: string },
 * }
 */

const GAUGE_CELLS = 10;

function effectiveStatus(status, nowMs) {
  const kind = status?.kind ?? 'available';
  if (kind === 'cooldown' && typeof status.until === 'number' && status.until <= nowMs) return 'available';
  return kind;
}

function reputationBlock(rep, t) {
  if (!rep || typeof rep !== 'object') return '';
  const max = Math.max(1, Number(rep.xpMax) || 1);
  const xp = Math.min(max, Math.max(0, Number(rep.xp) || 0));
  const filled = Math.floor((xp / max) * GAUGE_CELLS);
  const cells = Array.from({ length: GAUGE_CELLS }, (_, i) => html`<i class="${i < filled ? 'is-filled' : ''}"></i>`);

  return html`
    <section class="board__rep" aria-labelledby="board-rep-label">
      <div class="field">
        <span class="field__label" id="board-rep-label">${t('board.rep.label')}</span>
        <span class="field__fill">${t('board.rep.level', { level: rep.level ?? 1 })}</span>
      </div>
      <div class="gauge" role="progressbar" aria-valuemin="0" aria-valuemax="${max}" aria-valuenow="${xp}"
           aria-label="${t('board.rep.progress')}">
        <span class="gauge__cells">${cells}</span>
        <span class="gauge__count num">${xp}/${max}</span>
      </div>
      ${rep.nextUnlock && html`<p class="board__next">${t('board.rep.next', { unlock: rep.nextUnlock })}</p>`}
    </section>`;
}

export class JobBoard extends ViewElement {
  static view = 'job-board';
  static focusable = true;
  static ticking = true;

  #lastKind = null;

  template(payload, ui, { t, locale, now, seq }) {
    const kind = effectiveStatus(payload.status, now());
    this.#lastKind = kind;
    const canRequest = kind === 'available';
    const payout = payload.payout;

    return html`
      <chop-ticket tone="original" kind="sheet" role="dialog" aria-modal="true" aria-labelledby="board-title">
        <div class="ticket__body ruled">
          <header class="ticket__head">
            <h1 class="ticket__title" id="board-title">${payload.shopName || t('board.title')}</h1>
            <p class="ticket__form">${t('board.form')}</p>
            ${payload.ticketNo && html`<p class="ticket__no">${t('common.number')} <b class="num">${payload.ticketNo}</b></p>`}
          </header>

          <div class="form">
            <div class="field">
              <span class="field__label">${t('board.status.label')}</span>
              <span class="field__fill" data-ref="status" role="status">${this.#statusText(payload.status, kind, t, now())}</span>
            </div>
            ${payout && html`
              <div class="field">
                <span class="field__label">${t('board.payout')}</span>
                <span class="field__fill num">${formatMoney(payout.min, locale)} – ${formatMoney(payout.max, locale)}</span>
              </div>`}
          </div>

          ${reputationBlock(payload.reputation, t)}

          ${ui.result && html`<p class="ticket__result" data-tone="${ui.result.tone}" role="alert">${ui.result.text}</p>`}

          <chop-stamp class="ticket__stamp" slot-key="board-${seq}"
            label="${kind === 'available' ? '' : t(`stamp.${kind}`)}"></chop-stamp>
        </div>

        <div class="ticket__stub">
          <button type="button" class="btn btn--ink" data-action="request" data-focus="request" data-autofocus
            aria-busy="${ui.pending ? 'true' : 'false'}" ${canRequest ? '' : 'disabled'}>${ui.pending ? t('board.requesting') : t('board.request')}</button>
          <button type="button" class="btn btn--plain" data-action="close" data-focus="close">
            ${t('common.close')} <kbd>Esc</kbd>
          </button>
        </div>
      </chop-ticket>`;
  }

  #statusText(status, kind, t, nowMs) {
    if (kind === 'cooldown') {
      return t('board.status.cooldown', { time: formatDuration((status.until ?? nowMs) - nowMs) });
    }
    return t(`board.status.${kind}`);
  }

  onTick({ t, now }) {
    const { payload } = this.slice;
    const nowMs = now();
    const kind = effectiveStatus(payload.status, nowMs);
    if (kind !== this.#lastKind) {
      this.rerender();
      return;
    }
    const node = this.ref('status');
    if (node && kind === 'cooldown') node.textContent = this.#statusText(payload.status, kind, t, nowMs);
  }

  async onAction(action) {
    if (action === 'close') {
      this.requestClose();
      return;
    }
    if (action !== 'request' || this.slice.ui.pending) return;

    const { t } = this.ctx;
    // Every `open` bumps seq; a reply that outlives this opening must not touch a reopened board.
    const openedSeq = this.slice.seq;
    this.setUi({ pending: true, result: null });
    const reply = await this.deps.bridge.post('requestJob', {});
    if (!this.slice.open || this.slice.seq !== openedSeq) return;

    this.setUi({
      pending: false,
      result: reply.ok
        ? { tone: 'ok', text: t('board.accepted') }
        : { tone: 'error', text: errorText(t, reply.error) },
    });
  }
}
