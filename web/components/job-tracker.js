import { ViewElement } from './view-element.js';
import { html } from '../core/dom.js';
import { formatDuration } from '../core/i18n.js';

/**
 * <chop-job-tracker> — canary workshop copy pinned to the screen edge during a job.
 * Never takes NUI focus and never receives pointer events.
 *
 * payload = {
 *   vehicle:   { label: string, plate: string },
 *   stage:     'pickup' | 'deliver' | 'scrap',
 *   status?:   'active' | 'completed' | 'expired' | 'cancelled'   (default 'active'),
 *   expiresAt?: epochMs,            // counted down locally, no polling
 *   parts?:    [{ id: string, label: string, removed: boolean }],
 *   partner?:  string,
 * }
 */

const STAGES = ['pickup', 'deliver', 'scrap'];
const URGENT_MS = 60_000;

function effectiveStatus(payload, nowMs) {
  const status = payload.status ?? 'active';
  if (status === 'active' && typeof payload.expiresAt === 'number' && payload.expiresAt <= nowMs) return 'expired';
  return status;
}

export class JobTracker extends ViewElement {
  static view = 'job-tracker';
  static focusable = false;
  static ticking = true;

  #lastStatus = null;

  template(payload, ui, { t, now, seq }) {
    const status = effectiveStatus(payload, now());
    this.#lastStatus = status;
    const vehicle = payload.vehicle ?? {};
    const stageIndex = Math.max(0, STAGES.indexOf(payload.stage));
    const parts = Array.isArray(payload.parts) ? payload.parts : [];
    const removed = parts.filter((part) => part.removed).length;
    const hasTimer = typeof payload.expiresAt === 'number' && status === 'active';

    return html`
      <chop-ticket tone="canary" kind="slip" aria-label="${t('tracker.title')}">
        <div class="ticket__body ruled">
          <header class="slip__head">
            <span class="slip__vehicle">${vehicle.label ?? ''}</span>
            ${vehicle.plate && html`<span class="plate num">${vehicle.plate}</span>`}
          </header>

          <ol class="stages">
            ${STAGES.map((stage, i) => html`
              <li class="stages__step" data-state="${i < stageIndex ? 'done' : i === stageIndex ? 'current' : 'todo'}"
                  ${i === stageIndex ? 'aria-current="step"' : ''}>
                <span class="stages__no num">${i + 1}</span>${t(`tracker.stage.${stage}`)}
              </li>`)}
          </ol>

          ${hasTimer && html`
            <p class="slip__timer">
              <span class="field__label">${t('tracker.timeLeft')}</span>
              <span class="timer num" data-ref="timer"></span>
            </p>`}

          ${parts.length > 0 && html`
            <div class="checklist">
              <p class="checklist__head">
                <span class="field__label">${t('tracker.parts')}</span>
                <span class="num">${removed}/${parts.length}</span>
              </p>
              <ul>
                ${parts.map((part) => html`
                  <li class="checklist__item" data-removed="${part.removed ? 'true' : 'false'}">
                    <span class="checkbox" aria-hidden="true"></span>
                    <span class="checklist__label">${part.label}</span>
                    <span class="visually-hidden">${part.removed ? t('tracker.removed') : t('tracker.remaining')}</span>
                  </li>`)}
              </ul>
            </div>`}

          ${payload.partner && html`
            <div class="field field--inline">
              <span class="field__label">${t('tracker.partner')}</span>
              <span class="field__fill">${payload.partner}</span>
            </div>`}

          <chop-stamp class="ticket__stamp" slot-key="tracker-${seq}" label="${t(`stamp.${status}`)}"
            data-status="${status}"></chop-stamp>
        </div>
      </chop-ticket>`;
  }

  onTick({ now }) {
    const { payload } = this.slice;
    const nowMs = now();
    if (effectiveStatus(payload, nowMs) !== this.#lastStatus) {
      this.rerender();
      return;
    }
    const node = this.ref('timer');
    if (!node) return;
    const left = payload.expiresAt - nowMs;
    const text = formatDuration(left);
    if (node.textContent !== text) node.textContent = text;
    node.toggleAttribute('data-urgent', left <= URGENT_MS);
  }
}
