/**
 * Safe string templating for light-DOM components.
 *
 * Every `${value}` in an `html` template is HTML-escaped unless it is itself
 * the result of `html` (or explicitly wrapped with `raw`). Arrays are joined.
 * `false`, `null` and `undefined` render as nothing, which keeps conditionals
 * readable: html`${cond && html`<p>…</p>`}`.
 */

const SAFE = Symbol('safe-html');

const ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

export function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (ch) => ESCAPES[ch]);
}

function toSafe(value) {
  if (value === false || value === null || value === undefined) return '';
  if (Array.isArray(value)) return value.map(toSafe).join('');
  if (value && value[SAFE]) return value.value;
  return escapeHtml(value);
}

export function raw(value) {
  return { [SAFE]: true, value: String(value) };
}

export function html(strings, ...values) {
  let out = strings[0];
  for (let i = 0; i < values.length; i += 1) out += toSafe(values[i]) + strings[i + 1];
  return raw(out);
}

export function render(host, template) {
  host.innerHTML = toSafe(template);
}
