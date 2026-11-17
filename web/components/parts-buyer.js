import { ViewElement } from './view-element.js';
import { html } from '../core/dom.js';
import { errorText, formatMoney } from '../core/i18n.js';

/**
 * <chop-parts-buyer> — pink receipt copy at the sell ped.
 *
 * payload = {
 *   items: [{ item: string, label: string, price: number, owned: number }],
 * }
 *
 * `sellItem` reply data (all optional): { item, label, count, total, owned }.
 * `owned` is the remaining amount after the sale (defaults to 0). Lua may also
 * push an `update` with fresh `items`; that always wins.
 */

function rowsOf(payload) {
  return Array.isArray(payload.items) ? payload.items : [];
}

export class PartsBuyer extends ViewElement {
  static view = 'parts-buyer';
  static focusable = true;

  template(payload, ui, { t, locale }) {
    const rows = rowsOf(payload);
    const total = rows.reduce((sum, row) => sum + (Number(row.price) || 0) * (Number(row.owned) || 0), 0);
    const pending = ui.pendingItem ?? null;

    return html`
      <chop-ticket tone="pink" kind="sheet" role="dialog" aria-modal="true" aria-labelledby="buyer-title">
        <div class="ticket__body ruled">
          <header class="ticket__head">
            <h1 class="ticket__title" id="buyer-title">${t('buyer.title')}</h1>
            <p class="ticket__form">${t('buyer.form')}</p>
          </header>

          ${rows.length === 0
            ? html`<p class="ledger__empty">${t('buyer.empty')}</p>`
            : html`
              <table class="ledger">
                <thead>
                  <tr>
                    <th scope="col">${t('buyer.col.part')}</th>
                    <th scope="col" class="is-num">${t('buyer.col.owned')}</th>
                    <th scope="col" class="is-num">${t('buyer.col.price')}</th>
                    <th scope="col" class="is-num">${t('buyer.col.subtotal')}</th>
                    <th scope="col"><span class="visually-hidden">${t('buyer.col.action')}</span></th>
                  </tr>
                </thead>
                <tbody>
                  ${rows.map((row) => {
                    const owned = Number(row.owned) || 0;
                    const busy = pending === row.item;
                    return html`
                      <tr data-empty="${owned === 0 ? 'true' : 'false'}">
                        <th scope="row" class="ledger__part">${row.label}</th>
                        <td class="is-num num">${owned}</td>
                        <td class="is-num num">${formatMoney(row.price, locale)}</td>
                        <td class="is-num num ledger__fill">${owned > 0 ? formatMoney(row.price * owned, locale) : ''}</td>
                        <td class="ledger__action">
                          <button type="button" class="btn btn--line" data-action="sell" data-item="${row.item}"
                            data-focus="sell-${row.item}" aria-busy="${busy ? 'true' : 'false'}"
                            aria-label="${t('buyer.sellAllOf', { label: row.label })}"
                            ${owned === 0 || (pending && !busy) ? 'disabled' : ''}>${busy ? t('buyer.selling') : t('buyer.sellAll')}</button>
                        </td>
                      </tr>`;
                  })}
                </tbody>
                <tfoot>
                  <tr>
                    <th scope="row" colspan="3">${t('buyer.total')}</th>
                    <td class="is-num num ledger__total">${formatMoney(total, locale)}</td>
                    <td></td>
                  </tr>
                </tfoot>
              </table>`}

          ${ui.result && html`<p class="ticket__result" data-tone="${ui.result.tone}" role="status">${ui.result.text}</p>`}
        </div>

        <div class="ticket__stub">
          <button type="button" class="btn btn--plain" data-action="close" data-focus="close">
            ${t('common.close')} <kbd>Esc</kbd>
          </button>
        </div>
      </chop-ticket>`;
  }

  async onAction(action, el) {
    if (action === 'close') {
      this.requestClose();
      return;
    }
    if (action !== 'sell' || this.slice.ui.pendingItem) return;

    const item = el.dataset.item;
    const row = rowsOf(this.slice.payload).find((entry) => entry.item === item);
    if (!row) return;

    const { t, locale } = this.ctx;
    this.setUi({ pendingItem: item, result: null });
    const reply = await this.deps.bridge.post('sellItem', { item });
    if (!this.slice.open) return;

    if (reply.ok) {
      const data = reply.data ?? {};
      const remaining = Number.isFinite(data.owned) ? data.owned : 0;
      this.patchPayload({
        items: rowsOf(this.slice.payload).map((entry) => (entry.item === item ? { ...entry, owned: remaining } : entry)),
      });
      this.setUi({
        pendingItem: null,
        result: {
          tone: 'ok',
          text: t('buyer.sold', {
            count: data.count ?? row.owned,
            label: data.label ?? row.label,
            total: formatMoney(data.total ?? row.price * row.owned, locale),
          }),
        },
      });
    } else {
      this.setUi({ pendingItem: null, result: { tone: 'error', text: errorText(t, reply.error) } });
    }
  }
}
