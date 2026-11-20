/**
 * Translation and number formatting.
 *
 * Strings always come from Lua (`init` message). A fallback dictionary can be
 * registered for dev mode only; in game a missing key renders as the key
 * itself so the gap is visible instead of silently blank.
 *
 * Placeholders use `{name}`: t('buyer.sold', { count: 3 }) with "Sold {count}".
 */

let fallback = {};

export function setFallbackStrings(strings) {
  fallback = strings && typeof strings === 'object' ? strings : {};
}

export function createTranslator(locale) {
  const strings = locale.strings;
  function t(key, vars) {
    const template = strings[key] ?? fallback[key] ?? key;
    if (!vars) return template;
    return template.replace(/\{(\w+)\}/g, (match, name) => (name in vars ? String(vars[name]) : match));
  }
  t.has = (key) => key in strings || key in fallback;
  return t;
}

/** Maps a reply error code to `errors.<code>`, or `errors.generic` when unknown. */
export function errorText(t, code) {
  const key = `errors.${code}`;
  return t.has(key) ? t(key) : t('errors.generic');
}

export function formatMoney(amount, locale) {
  const value = Number.isFinite(amount) ? amount : 0;
  let digits;
  try {
    digits = new Intl.NumberFormat(locale.lang, { maximumFractionDigits: 0 }).format(value);
  } catch {
    digits = String(Math.round(value));
  }
  return `${locale.currency}${digits}`;
}

/** 754000 -> "12:34", 3_754_000 -> "1:02:34". Negative values clamp to zero. */
export function formatDuration(ms) {
  const total = Math.max(0, Math.ceil(ms / 1000));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const seconds = total % 60;
  const pad = (n) => String(n).padStart(2, '0');
  return hours > 0 ? `${hours}:${pad(minutes)}:${pad(seconds)}` : `${pad(minutes)}:${pad(seconds)}`;
}
