# NUI contract — version 1

The single agreement between `client/nui.lua` and `web/`. Change it here first, then on both sides, and bump `v` on any breaking change. Additions (new views, new optional payload fields, new actions) are not breaking: `v` stays `1`.

## How the pieces fit

```
Lua  Nui.open / update / close / setLocale ──SendNUIMessage──▶ core/bridge.js ──▶ core/state.js (reducer) ──▶ store ──▶ views
Lua  Nui.on(action, handler)  ◀──fetch https://<resource>/<action>── bridge.post(action, data) ◀── views
```

- `core/bridge.js` is the only code that listens to `window` messages or calls `fetch`.
- `core/state.js` is the only code that changes state. Views read from the store and render.
- A view's `payload` belongs to Lua. A view's `ui` (pending flags, result lines) belongs to the page.

## Envelope (Lua → NUI)

Every message is a JSON object:

| field   | type   | notes |
|---------|--------|-------|
| `v`     | number | contract version, currently `1`. The page warns on mismatch. |
| `clock` | number | Lua clock in epoch milliseconds (`GetCloudTimeAsInt() * 1000`). The page uses it to correct its own clock before counting down to any deadline. |
| `type`  | string | `init`, `open`, `update` or `close`. |

`Nui.*` adds `v` and `clock` for you.

### `init`

```json
{ "type": "init", "locale": { "lang": "es", "currency": "$", "strings": { "board.title": "Desguace" } } }
```

- `strings` may be flat (`"board.title"`) or nested (`{ "board": { "title": "…" } }`); the page flattens it.
- `lang` drives number formatting (`Intl.NumberFormat`). `currency` is a prefix symbol.
- Every visible string comes from here. In game, a missing key is shown as the key itself. `web/dev/locale-en.js` lists every key and is the reference for locale files.
- Placeholders are `{name}`.

### `open`

```json
{ "type": "open", "view": "job-board", "payload": { } }
```

Replaces the view's payload and shows it. Re-opening an open view restarts its entry animation.

### `update`

```json
{ "type": "update", "view": "job-tracker", "payload": { "stage": "scrap" } }
```

Shallow merge into the open view's payload. Arrays (`parts`, `items`) are replaced whole. Ignored if the view is closed.

### `close`

```json
{ "type": "close", "view": "parts-buyer" }
```

Omit `view` to close everything.

## Callbacks (NUI → Lua)

POST `https://<resource>/<action>` with a JSON body. Every reply is:

```json
{ "ok": true, "data": { } }
{ "ok": false, "error": "code" }
```

The page shows `errors.<code>` from the locale, or `errors.generic` when that key does not exist. Transport problems never reject: they resolve to `{ ok: false, error: "transport" | "timeout" | "bad_reply" }` (timeout: 10 s).

| action       | body                | reply `data` | notes |
|--------------|---------------------|--------------|-------|
| `ready`      | `{ v }`             | `{ v }`      | Reserved. Sent once on page boot; Lua then sends the locale and flushes queued messages. |
| `close`      | `{ view }`          | —            | Reserved. Sent on Escape or the close button. The page hides the view immediately; Lua releases focus and runs the view's `onClose(view, 'nui')`. |
| `requestJob` | `{}`                | free, e.g. `{ plate }` | Errors used today: `already_working`, `cooldown`, `no_police`, `no_scrap`. |
| `sellItem`   | `{ item }`          | `{ item?, label?, count?, total?, owned?, remainingTotal? }` | `total` is what was paid, `owned` what remains after the sale (default 0) and `remainingTotal` what the remainder is worth. Errors: `no_item`, `too_far`. |
| `answerInvite` | `{ accept: boolean }` | — | Answer from the `partner-invite` sheet. Lua closes the sheet on success. Error: `expired` (no invite waiting); the page then closes the sheet itself, which Lua also reads as a decline. |

Lua registers them with `Nui.on(action, function(data) return ok, dataOrErrorCode end)`. The wrapper rejects non-table bodies with `bad_payload` and turns thrown errors into `internal`.

## Views and payloads

Times are absolute epoch milliseconds on the same clock as `clock`. The page counts down locally; Lua never needs to resend a timer.

### `job-board` — menu, takes focus

```jsonc
{
  "shopName": "Sandy Shores Chop",          // optional, falls back to board.title
  "ticketNo": "0412",                        // optional, printed in red top right
  "status": { "kind": "available" },         // available | cooldown | no_police | no_scrap | busy
  // cooldown: { "kind": "cooldown", "until": 1763400000000 } -> turns to available at 0
  "payout": { "min": 100, "max": 200 },      // optional
  "reputation": {                            // optional; the block renders only when present
    "level": 3, "xp": 340, "xpMax": 500,     // xp within the current level
    "nextUnlock": "Engine blocks"            // optional, already localised
  }
  // reputation is built by the server (Reputation.GetBoardBlock) and omitted when Config.Reputation is disabled.
  // Levels start at 0. At the max level the server sends xp = xpMax = 1 and no nextUnlock.
}
```

Primary action posts `requestJob`. Lua is expected to `close` the board on success.

### `job-tracker` — corner slip, never takes focus

```jsonc
{
  "vehicle": { "label": "Ubermacht Sentinel", "plate": "CHOP 412" },
  "stage": "pickup",                         // pickup | deliver | scrap
  "status": "active",                        // active | completed | expired | cancelled
  "expiresAt": 1763400000000,                // optional; past it, the slip stamps itself expired
  "parts": [ { "id": "door_dside_f", "label": "Front left door", "removed": false } ],
  "partner": "M. Reyes"                      // optional
}
```

Mark a part with `update` and the full `parts` array. Placement is set by `--tracker-top` / `--tracker-right` in `styles/tokens.css`.

Optional `log` — the slip's notes ("Notes" section), sent whole with `update` like `parts`:

```jsonc
"log": [ { "id": 7, "at": 1763400000000, "tone": "error", "text": "You have no space left" } ]
// id:   increasing number; the newest line (last) is marked once when its id is first seen
// at:   epoch ms, printed as HH:MM in the player's language
// tone: success | inform | error   (error is written in red)
// text: already localised by Lua
```

Lua keeps the last 5 lines (`LOG_SIZE` in `client/interact.lua`) and resets them when the tracker is opened.

### `parts-buyer` — menu, takes focus

```jsonc
{ "items": [ { "item": "vehicle_door", "label": "Door", "price": 45, "owned": 4, "total": 270 } ] }
```

`price` is the base price of one standard item. `total` (optional) is what the server pays for everything owned: each stack is priced by its `quality` metadata (`Config.SellPed.QualityMultiplier`), so it can be higher than `price × owned`. A row without `total` falls back to `price × owned`. The total row is the sum of the row amounts. Each row's "sell all" posts `sellItem`.

### `note` — loose note on the right edge, never takes focus

```jsonc
{ "tone": "inform", "text": "M. Reyes will start the scrap soon. Wait by the vehicle." }
// tone: success | inform | error -> red printed header note.<tone>; text already localised
```

A torn scrap of white paper placed above the tracker (its bottom edge sits `1rem` above `--tracker-top`), sliding in and out like the tracker. Lua closes it 5 s after opening (`NOTE_MS` in `client/interact.lua`); a new note replaces the old one and restarts that time.

### `partner-invite` — menu, takes focus

```jsonc
{ "from": "M. Reyes", "text": "M. Reyes asks for your help scrapping a vehicle.", "ticketNo": "CHOP 412" }
// text: already localised (partner_invite_desc); ticketNo: printed in red top right (the job plate)
```

Accept / Decline post `answerInvite`. Escape (reserved `close`) and a Lua close count as a decline. Lua closes it after 30 s without an answer (`INVITE_MS` in `client/interact.lua`).

### Where in-job messages go (Lua)

`ClientInteract.Feedback(kind, key, ...)` in `client/interact.lua` is the only place that picks the output: a `log` line when the tracker is open, otherwise a `note`, and `Editable.Client.Notify` when `Config.UseNUI` is false or the page is not ready. Errors of actions taken on an open sheet (`requestJob`, `sellItem`) are reply codes written on that sheet, not messages.

## Locale keys

`common.*`, `board.*`, `stamp.<kind|status>`, `tracker.*`, `note.<tone>`, `invite.*`, `buyer.*`, `errors.<code>`. The full list with English text is `web/dev/locale-en.js`.

## Dev mode

Outside FiveM (`GetParentResourceName` undefined) the page loads `dev/mock.js`: English fallback strings, mocked callbacks, and a toolbar that emits the same envelopes Lua sends. ES modules do not load from `file://`, so serve the folder:

```
npx serve web        # or: python -m http.server -d web
```

## Resource wiring

`fxmanifest.lua` needs:

```lua
ui_page 'web/index.html'
files { 'web/index.html', 'web/app.js', 'web/core/*.js', 'web/components/*.js', 'web/styles/*.css' }
```

`web/dev/` and this file do not need to ship.
