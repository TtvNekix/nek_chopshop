# Nekix ChopShop

Chop shop job for FiveM: steal a vehicle, drive it to the scrapyard, strip it for parts and sell them. Runs on ESX, QBCore and Qbox. Every decision (job, vehicle, parts, loot, payment, XP) is made on the server.

**Documentation in other languages:** [Español](docs/i18n/README.es.md) | [Português (Brasil)](docs/i18n/README.pt-br.md) | [Français](docs/i18n/README.fr.md) | [Deutsch](docs/i18n/README.de.md)

## Features

- **Frameworks:** ESX, QBCore and Qbox, detected automatically (`Config.Framework = 'auto'`).
- **Inventories:** ox_inventory, qs-inventory, core_inventory, ps-inventory and qb-inventory, detected automatically, plus a `custom` adapter for any other inventory.
- **Server-authoritative jobs:** the server picks the vehicle, spawns it, validates distances, timing and lockpick, and decides every reward. A modified client cannot give itself items, money or XP.
- **Vehicle tiers and loot:** low, mid and high tier vehicles with their own payout, item quality and loot table.
- **Reputation:** per-character XP and levels (oxmysql) that unlock vehicle tiers and perks.
- **More parts:** doors, hood, trunk, engine, front seats and wheels, with a server-enforced "remove this first" order.
- **Police:** minimum officers on duty and a dispatch alert with 9 supported scripts plus `custom`.
- **Vehicle keys:** the job owner gets the keys of the job vehicle after the lockpick, with 7 supported scripts plus `custom`.
- **Partner system:** the owner can invite a partner before scrapping; the partner shares the work and a share of the XP.
- **Time limits:** pickup and scrap timers; an expired job is cancelled and its scrapyard bay released.
- **Persistent cooldown:** stored in the resource KVP (no SQL), per character and per license, with an admin reset command.
- **Work-order NUI:** job board, job slip with in-sheet notes, loose notes, partner invite and parts buyer. Can be switched off.
- **10 languages** through ox_lib locales: en, es, fr, de, it, pt-br, pl, nl, tr, cs.
- **Discord logs** and a version checker.

## Requirements

| Resource | Notes |
| :--- | :--- |
| [ox_lib](https://github.com/overextended/ox_lib) | required |
| [ox_target](https://github.com/overextended/ox_target) | required |
| [oxmysql](https://github.com/overextended/oxmysql) | required (manifest dependency). With `Config.Reputation.Enabled = false` no SQL is run |
| OneSync | required (the server spawns the vehicles) |
| `qbx_core`, `es_extended` or `qb-core` | one of them |
| An inventory | `ox_inventory`, `qs-inventory`, `core_inventory`, `ps-inventory`, `qb-inventory` or a custom adapter |

Optional: a vehicle keys script and a police dispatch script (see "Vehicle keys" and "Police & dispatch").

## Installation

1. **Download** the resource and place the folder in your resources directory. Keep the folder name `nek_chopshop`: the exports use it (`exports.nek_chopshop`).
2. **Add the items** to your inventory. Open the guide for your inventory, copy the block and restart the inventory:

   | Inventory | Guide |
   | :--- | :--- |
   | ox_inventory | [docs/items/ox_inventory.md](docs/items/ox_inventory.md) |
   | qb-inventory | [docs/items/qb-inventory.md](docs/items/qb-inventory.md) |
   | ps-inventory | [docs/items/ps-inventory.md](docs/items/ps-inventory.md) |
   | qs-inventory | [docs/items/qs-inventory.md](docs/items/qs-inventory.md) |
   | core_inventory | [docs/items/core_inventory.md](docs/items/core_inventory.md) |
   | any other | [docs/items/custom.md](docs/items/custom.md) |

3. **Copy the item images** from the `[assets]` folder into your inventory images directory (`ox_inventory/web/images/`, `qb-inventory/html/images/`, ...; each guide names the folder). Every image is named after its item.
4. **Add the resource to `server.cfg`**, after its dependencies:

   ```cfg
   ensure ox_lib
   ensure ox_target
   ensure oxmysql
   ensure qbx_core            # or es_extended / qb-core
   ensure ox_inventory        # or your inventory
   ensure qbx_vehiclekeys     # optional: your vehicle keys script
   ensure ps-dispatch         # optional: your dispatch script
   ensure nek_chopshop
   ```

5. **Database:** nothing to import. The table `nek_chopshop_reputation` is created on the first start.
6. **Configuration:** leave `Config.Framework = 'auto'` and `Config.Inventory = 'auto'` unless you need to force one. Review [`shared/config.lua`](shared/config.lua).
7. **Language (optional):** add `setr ox:locale "es"` to `server.cfg` (see "Languages").
8. **Start the server** and check the console: it prints the framework and inventory it found, and warns about any item that is not registered.

## How a job works

1. The player asks for a job at the ped (target option or job board). The server checks cooldown, police on duty, reputation tier and a free scrapyard bay, then spawns the vehicle and marks it on the map.
2. The player lockpicks the vehicle (needs one of `Config.LockpickItems` and passes the minigame). The server gives the keys and sends the police alert.
3. The player drives it to the scrapyard.
4. At the scrapyard the player can invite a partner, then starts stripping.
5. Every removed part goes to the inventory. When all parts are gone the owner gets `Config.FinishReward` and, if enabled, money. The vehicle is destroyed.
6. The player sells the parts at the sell ped.

## Configuration overview

All options live in [`shared/config.lua`](shared/config.lua), each with a comment. Grouped by area:

### General

| Option | Description |
| :--- | :--- |
| `Config.Framework` | `'auto'` (default), `'esx'`, `'qbcore'` or `'qbox'`. Auto order: `qbx_core` > `es_extended` > `qb-core`. A forced framework that is not started falls back to auto-detection. |
| `Config.Inventory` | `'auto'` (default), `'ox_inventory'`, `'qs-inventory'`, `'core_inventory'`, `'ps-inventory'`, `'qb-inventory'` or `'custom'`. See "Inventory". |
| `Config.LockpickItems` | Items that allow lockpicking the job vehicle (any one is enough). Default `lockpick`, `advancedlockpick`, `advanced_lockpick`. |
| `Config.UseNUI` | `true` uses the NUI; `false` falls back to ox_lib menus and notifications. |
| `Config.Debug` | Debug prints. |
| `Config.AdminAce` | ACE allowed to use the admin command. See "Admin". |

### Jobs, rewards and time

| Option | Description |
| :--- | :--- |
| `Config.Cooldown` | Seconds between jobs (default 3600). Reputation perks can shorten it. |
| `Config.TimeLimit` | `Pickup` and `Scrap`, in minutes (defaults 20 and 10). Pickup runs from accepting the job until scrapping starts; scrap from starting until every part is removed. A job that exceeds either is cancelled. |
| `Config.Payment` | `Enable`, `Min`, `Max`: optional money per job (disabled by default). Multiplied by the tier `payout`. |
| `Config.FinishReward` | Item given to the owner when all parts are removed (default `veh_suspension`), or `false`. |
| `Config.ChopParts` | Parts that can be removed. It is the reward whitelist: the server only rewards parts listed here. See "Parts". |
| `Config.Coords` | `Spawns` (vehicle spawn points) and `Scrap` (scrapyard bays). |
| `Config.Tiers` | Vehicle tiers. See "Vehicle tiers & loot". |
| `Config.Reputation` | XP, levels, perks, decay. See "Reputation". |

### Peds and selling

| Option | Description |
| :--- | :--- |
| `Config.Ped` | Job ped: `Model`, `Coords`, `Scenario`, `Target` (ox_target options), `Blip`. |
| `Config.SellPed` | Sell ped: `Enable`, `Model`, `Coords`, `Scenario`, `Items` (item, base price, label), `QualityMultiplier`, `Blip`. |

Labels (`label`, blip `Label`, target `label`) take a locale key; a literal text also works.

### Police and vehicle keys

| Option | Description |
| :--- | :--- |
| `Config.Police` | `MinOnDuty`, `JobType`, `Jobs`, `Dispatch`. See "Police & dispatch". |
| `Config.VehicleKeys` | `System`, `RemoveOnEnd`. See "Vehicle keys". |

### Security (anti-exploit)

`Config.Security` holds the server-side thresholds (distances in meters, times in milliseconds):

| Option | Default | Description |
| :--- | :--- | :--- |
| `PedDistance` | 10.0 | Max distance to the job ped to request a job. |
| `SellDistance` | 10.0 | Max distance to the sell ped to sell. |
| `ScrapDistance` | 15.0 | Max distance from the vehicle to the scrap point to start scrapping. |
| `PartDistance` | 6.0 | Max distance from the player to the vehicle to remove a part. |
| `PartnerDistance` | 20.0 | Max distance between owner and partner when assigning. |
| `PartInterval` | 2000 | Min time between two part removals by the same player. |
| `SpawnClearRadius` | 3.0 | A spawn point is skipped if a vehicle is within this radius. |
| `MaxAverageSpeed` | 60.0 | m/s. A delivery from spawn to scrapyard faster than this is treated as a teleport and rejected. |
| `WarnThrottle` | 30 | Seconds between suspicious-request logs for the same player. |
| `DispatchDistance` | 10.0 | Max distance to the job vehicle when the lockpick report arrives. |

### Logs

| Option | Description |
| :--- | :--- |
| `Config.Discord` | `Username`, `AvatarUrl`, embed `Color`s. The webhook URL is **not** here: set `Editable.Webhook` in `editable/server.lua`. |
| `Config.Logs` | `EnableItem`, `EnablePay`, `EnableFinish`, `EnableWarn`, `EnableReputation`, `Compact`. |

Discord logs use the server language.

## Inventory

`Config.Inventory = 'auto'` uses the first started inventory of this list:

| # | Resource | Frameworks | Notes |
| :--- | :--- | :--- | :--- |
| 1 | `ox_inventory` | ESX, QBCore, Qbox | Full support. |
| 2 | `qs-inventory` | ESX, QBCore, Qbox | Written from the vendor docs. |
| 3 | `core_inventory` | ESX, QBCore, Qbox | Written from the vendor docs; selling by quality is degraded. |
| 4 | `ps-inventory` | QBCore | Space check is an estimate; selling by quality is degraded. |
| 5 | `qb-inventory` | QBCore | Selling by quality is degraded. |

- **Late start:** if no inventory is running when the resource starts, it waits and picks one as soon as a listed resource starts. Still, start your inventory before nek_chopshop.
- **Force one:** set the resource name. If it is not started, a console warning is printed and auto-detection is used.
- **Any other inventory:** `Config.Inventory = 'custom'` and fill `Editable.Inventory` in `editable/server.lua`. See [docs/items/custom.md](docs/items/custom.md).
- **Quality metadata:** ox_inventory stores the tier quality in `metadata.quality`; the other inventories use `chopQuality`.
- Known limitations of each inventory are listed at the end of its item guide.

## Police & dispatch

### Minimum police on duty

`Config.Police.MinOnDuty` is the number of officers that must be on duty to hand out a job (`0` disables it). The request is refused on the server and the job board shows "Not enough police on duty".

- **Qbox / QBCore:** counts on-duty players whose job type is `Config.Police.JobType` (default `'leo'`). Set `JobType = false` to count the job names in `Config.Police.Jobs` instead.
- **ESX:** counts players with a job in `Config.Police.Jobs` whose `job.onDuty` is not `false` (older ESX without duty counts everyone in the job).
- A tier can add `minPolice`; the effective requirement is the higher of the two.

### Alert

One alert per job, sent by the server (from its job sweep, or when the vehicle is delivered) so a modified client cannot skip it. The thief's client may trigger it earlier, right after the lockpick; the server checks that the caller owns the job, is in the pickup stage, is next to the vehicle (`Config.Security.DispatchDistance`) and has not alerted yet. Location, plate and model always come from the server.

`Config.Police.Dispatch.System`:

| Value | Behaviour |
| :--- | :--- |
| `'auto'` | First started script of the list below. |
| a script name | Forces that script. |
| `'custom'` | Calls your own code (see below). |
| `false` | No alert. |

Supported scripts, in auto-detection order:

| # | Resource | Runs on |
| :--- | :--- | :--- |
| 1 | `ps-dispatch` | client |
| 2 | `cd_dispatch` | client |
| 3 | `qs-dispatch` | client |
| 4 | `rcore_dispatch` | client |
| 5 | `core_dispatch` | server |
| 6 | `tk_dispatch` | client |
| 7 | `origen_police` | client |
| 8 | `lb-tablet` | server |
| 9 | `linden_outlawalert` | client |

Other options of `Config.Police.Dispatch`: `Code` (radio code, default `10-35`), `CodeName` (ps-dispatch only), `Title` and `Message` (locale keys `dispatch_title` / `dispatch_message`; the message gets the model and the plate) and `Blip` (`Sprite`, `Color`, `Scale`, `Time` in seconds).

**Custom:** set `System = 'custom'` and fill `Editable.Client.DispatchAlert(data)` (`editable/client.lua`) and/or `Editable.Server.DispatchAlert(data, source)` (`editable/server.lua`). `data` is `{ coords, plate, model, code, title, message, jobs, jobType }`; the client version also gets `modelLabel` and `vehicle` (entity).

## Vehicle keys

Key scripts (for example `qbx_vehiclekeys`) do not let a player start a vehicle they have no keys for. After a successful lockpick the server gives the owner the keys of the job vehicle, once per job and only with a lockpick item held. Partners never get keys.

`Config.VehicleKeys`:

| Option | Behaviour |
| :--- | :--- |
| `System = 'auto'` | First started script of the list below. |
| `System = '<resource>'` | Forces that script (no keys if it is not started). |
| `System = 'custom'` | Calls `Editable.Server.GiveVehicleKeys(src, vehicle, plate, model)` and `Editable.Server.RemoveVehicleKeys(...)` in `editable/server.lua`. |
| `System = false` | No keys are given (ESX without a key script, for example). |
| `RemoveOnEnd = true` | Takes the keys back when the job ends, before the vehicle is deleted. |

Supported scripts, in auto-detection order: `qbx_vehiclekeys`, `qs-vehiclekeys`, `wasabi_carlock`, `MrNewbVehicleKeys`, `ak47_vehiclekeys`, `vehicles_keys`, `qb-vehiclekeys`.

Not built in (use `'custom'`): Renewed-Vehiclekeys, cd_garage keys, t1ger_keys, okokGarage / okokVehicleKeys.

## Vehicle tiers & loot

The server chooses the vehicle. `Config.Tiers` groups the models into tiers (`low`, `mid`, `high` by default):

| Field | Description |
| :--- | :--- |
| `label` | Locale key (or text) shown when the job starts. |
| `weight` | Relative chance of the tier among the tiers the player qualifies for. |
| `minLevel` | Reputation level needed. Ignored when the reputation is disabled. |
| `minPolice` | Optional. Officers on duty needed for this tier. |
| `payout` | Multiplier for the final payment (`Config.Payment`). |
| `quality` | Quality given to the part items of this tier: `standard`, `premium` or `exotic`. Items with different quality do not stack. |
| `models` | Vehicle model names; one is picked at random. |
| `loot` | Extra rolls for every removed part: `{ item, chance (0-100), min, max, parts = { bones }, quality = true }`. |

- Tier, model and loot are rolled on the server.
- Before a part is removed the server checks that the part, its bonus items and all loot fit at once. If not, nothing is given and the part stays on the car.
- **Selling:** the sell ped pays `price x QualityMultiplier[quality] x reputation sellMultiplier` for every stack. `Config.SellPed.QualityMultiplier` defaults: standard 1.0, premium 1.5, exotic 2.5.
- Loot-only items (`scrap_metal`, `sport_wheel`, `turbo_kit`) must be registered in your inventory and listed in `Config.SellPed.Items` to be sold.
- A config that still has the old flat `Config.Vehicles` list and no `Config.Tiers` keeps working as a single `low` tier.

## Reputation

Saved per character in the oxmysql table `nek_chopshop_reputation` (`identifier`, `xp`, `jobs`, `last_job`), created automatically. `identifier` is the framework character id (ESX `identifier`, QBCore/Qbox `citizenid`).

- **Earning (server only):** finished job gives the owner `Base + PerPart x parts removed + TimeBonusMax x (fraction of the scrap time left)`. The partner gets `PartnerShare` (0-1) of that. A job out of time or with a lost vehicle costs the owner `PenaltyExpired`; leaving the server with an active job costs `PenaltyAbandoned`. XP never goes below 0.
- **Levels** (`Config.Reputation.Levels`): the first entry is level 0 (`xp = 0`). Each level lists its own perks:

| Perk | Effect |
| :--- | :--- |
| `sellMultiplier` | Multiplies the sell ped price (on top of the quality multiplier). |
| `cooldownMultiplier` | Multiplies `Config.Cooldown` when a job is taken (0-1). |
| `extraPartChance` | Chance (0-100) of one extra copy of each removed part. |
| vehicle tiers | Unlocked through `Config.Tiers[].minLevel` (default: mid at level 2, high at level 4). |

- **Decay** (`Config.Reputation.Decay`, off by default): every full week without a finished job removes `PerWeek` XP. Computed when the reputation is read; there is no timer.
- **Disabled** (`Enabled = false`): no XP, no perks, every tier available, no SQL.
- The job board shows level and progress; a level up sends a notification and, with `Config.Logs.EnableReputation`, a Discord log.

## Parts

`Config.ChopParts` entries: `bone`, `part` (door or wheel index), `item`, `label` (locale key), `isDoor` / `isWheel`, `bonus` (extra items), `anim` (`'repair'` for the under-hood animation), `optional` and `requires`.

- Default parts: 4 doors, hood (gives `car-battery`), trunk, engine (needs the hood removed), 2 front seats (need their door removed) and 4 wheels.
- Only the 4 wheels are mandatory. Every other part is optional: it is part of the job only if the vehicle model has that bone, so a model that lacks a bone never leaves the job unfinishable.
- `requires` is enforced on the server. If the required part is not part of the job, the requirement counts as satisfied.

## Languages

All player-facing text lives in `locales/<lang>.json`, loaded with the ox_lib locale module.

Included: English (`en`), Spanish (`es`), French (`fr`), German (`de`), Italian (`it`), Brazilian Portuguese (`pt-br`), Polish (`pl`), Dutch (`nl`), Turkish (`tr`) and Czech (`cs`).

- **Switch language:** add `setr ox:locale "es"` to `server.cfg` (default `en`). Players can also pick a language in the ox_lib settings menu; the NUI refreshes when they do.
- **Fallback:** a missing key falls back to English; a missing file falls back to English.
- **Add a language:** copy `locales/en.json` to `locales/<code>.json` (same code as in `ox_lib/locales`, e.g. `ru`, `zh-cn`), translate the values and keep the keys. Keep `%s` / `%d` in the same order and the `{placeholders}` of the `nui` section unchanged. Do not use `${...}` inside texts.
- Do not edit `ChopLocale` / `LoadChopLocale` in the config.

## Admin

| Command | Description |
| :--- | :--- |
| `chopshop_resetcd all` | Clears the job cooldown of every character and license. |
| `chopshop_resetcd <player id>` | Clears the cooldown of one connected player (current character and license). |
| `chopshopui` | Player command: closes every NUI view and releases the mouse focus if a page error leaves it stuck. |

Cooldowns live in this resource's KVP storage (the server's `db/` folder), not in MySQL.

`Config.AdminAce` (default `'admin'`):

- Players with this ACE can run `chopshop_resetcd` in game (the ACE `command.chopshop_resetcd` also works). The server console can always run it.
- Players with this ACE skip the anti-teleport delivery check, so staff can test with teleports.

```cfg
add_ace group.admin admin allow
```

## Exports

Use the resource folder name in `exports[...]`.

### Client

```lua
-- Returns { active = boolean, pedCoords = vector4 }
-- active: the local player has an active chop job. pedCoords: Config.Ped.Coords.
local status = exports.nek_chopshop:GetJobStatus()
if status.active then
    print('Working on a chop job')
end
```

### Server

```lua
-- GetReputation(identifier: string) -> { xp = number, level = number, jobs = number } | nil
-- nil when the reputation is disabled, the identifier is invalid, or the database could not be read.
-- May wait for the database the first time an identifier is read: call it from a thread.
CreateThread(function()
    local rep = exports.nek_chopshop:GetReputation(citizenid)
    if rep then print(rep.xp, rep.level, rep.jobs) end
end)

-- AddReputation(identifier: string, amount: number, reason?: string) -> boolean
-- amount: non-zero, positive adds and negative removes (fractions are truncated, max 1000000).
-- reason: text for the log (cut to 100 characters, default 'export').
-- Saved asynchronously, printed to the console and logged to Discord (Config.Logs.EnableReputation).
-- Returns false for an invalid identifier or amount, when the reputation is disabled, or when the
-- row could not be read (the change is then queued and applied once on the next successful read).
-- May wait for the database the first time an identifier is used: call it from a thread.
CreateThread(function()
    exports.nek_chopshop:AddReputation(citizenid, 50, 'event reward')
    exports.nek_chopshop:AddReputation(citizenid, -25, 'admin correction')
end)
```

## Editable hooks

These files are meant to be edited:

| File | Function | Purpose |
| :--- | :--- | :--- |
| `editable/server.lua` | `Editable.Webhook` | Discord webhook URL. |
| `editable/server.lua` | `Editable.Server.SendDiscordLog(title, description, color)` | Custom log delivery. |
| `editable/server.lua` | `Editable.Server.CustomReward(source)` | Extra reward when a job is finished (crypto, XP, items...). |
| `editable/server.lua` | `Editable.Server.DispatchAlert(data, source)` | Custom dispatch (`System = 'custom'`). |
| `editable/server.lua` | `Editable.Server.GiveVehicleKeys` / `RemoveVehicleKeys` | Custom keys (`System = 'custom'`). |
| `editable/server.lua` | `Editable.Inventory` | Custom inventory adapter (`Config.Inventory = 'custom'`). |
| `editable/client.lua` | `Editable.Client.MiniGame()` | Lockpick minigame; return `true` on success. Default `lib.skillCheck`. |
| `editable/client.lua` | `Editable.Client.DispatchAlert(data)` | Custom dispatch on the thief's client. |
| `editable/client.lua` | `Editable.Client.Notify(data)` | Notification style (used when the NUI is off or not ready). |

Each function has commented examples and the exact shape of its arguments.

## NUI customisation

The NUI lives in `web/` (plain Web Components, no build step). The Lua side and the page share one contract: [web/CONTRACT.md](web/CONTRACT.md) (messages, callbacks, view payloads, locale keys).

- **Colors, fonts, spacing and placement** are CSS variables in `web/styles/tokens.css`: paper and ink colors (`--paper-original`, `--ink`, `--stamp`...), fonts (`--font-print`, `--font-hand`, `--font-num`) and the job slip position (`--tracker-top`, `--tracker-right`).
- **Texts** come from the `nui` section of `locales/<lang>.json`.
- `Config.UseNUI = false` removes the NUI and uses ox_lib menus and notifications.

## Items and icons

Every part, bonus, finish reward and tier loot item is checked against the inventory item list on start and whenever the inventory restarts (skipped if the inventory has no item list export). Unknown loot entries are dropped with a console warning; unknown part, bonus and reward items are only reported.

| Item | Source |
| :--- | :--- |
| `vehicle_door`, `vehicle_hood`, `vehicle_trunk`, `vehicle_engine`, `vehicle_seat`, `veh_wheels` | Parts |
| `car-battery` | Bonus of the hood |
| `veh_suspension` | Default `Config.FinishReward` |
| `scrap_metal`, `sport_wheel`, `turbo_kit` | Tier loot |

Icons are in `[assets]`, named after the item. They come from the RAINMAD image gallery (https://items.rainmad.com/).

## Troubleshooting

| Problem | Cause and fix |
| :--- | :--- |
| `No such export getSharedObject in resource es_extended` (or similar) | `Config.Framework` is forced to a framework that is not started. Set `'auto'`. Since 2.0.0 a forced framework that is not started falls back to auto-detection and prints a warning. |
| `... item "x" is not registered in <inventory>` in the console | The item is missing in your inventory. Add it from [docs/items](docs/items/). |
| `No supported inventory detected` | No listed inventory is started. Start it before nek_chopshop, or use `'custom'`. |
| The player has no keys after the lockpick | Check `Config.VehicleKeys.System`: your key script may not be supported (use `'custom'`) or may not be started. |
| No police alert | Check `Config.Police.Dispatch.System`: the script may not be started or supported (use `'custom'`). |
| "Not enough police on duty" | `Config.Police.MinOnDuty` (or the tier `minPolice`) is higher than the officers on duty. Set it to `0` to disable. |
| "You have to wait N minutes before working again." | Job cooldown. Staff can run `chopshop_resetcd <id>` or `chopshop_resetcd all`. |
| "Nobody drives here that fast. Wait N s and try again." | The anti-teleport check rejected a delivery faster than `Config.Security.MaxAverageSpeed`. Wait the shown seconds. Staff with `Config.AdminAce` skip the check. |
| The mouse stays on screen | Run `/chopshopui`. |
| `Could not check for updates.` | The server cannot reach GitHub. Harmless. |
| Reputation table errors | oxmysql is not working. Check its connection string. |

Set `Config.Debug = true` for extra console output.

Note: quoted messages are the English texts; in game they appear in the configured language.

## Updating from v1

Breaking changes:

- **Items:** 6 new items (`vehicle_trunk`, `vehicle_engine`, `vehicle_seat`, `scrap_metal`, `sport_wheel`, `turbo_kit`). Register them and copy their images (see "Installation").
- **Image rename:** `[assets]/vehicle_wheel.png` is now `[assets]/veh_wheels.png` (the item name `veh_wheels` did not change). Rename it in your inventory images if you copied the old one.
- **Locales:** `Config.Locales` is gone. Texts moved to `locales/*.json` (ox_lib). If you edited texts, copy them into your language file.
- **Vehicles:** the flat `Config.Vehicles` list became `Config.Tiers` (the old list still works as one `low` tier).
- **New config sections:** `Config.Inventory`, `Config.Police`, `Config.VehicleKeys`, `Config.TimeLimit`, `Config.Reputation`, `Config.Tiers`, `Config.AdminAce`, `Config.UseNUI`, `Config.SellPed.QualityMultiplier`. `Config.Framework` now defaults to `'auto'`. Merge them from the new `shared/config.lua`.
- **Editable hooks:** `Editable.Client.DispatchAlert` now receives a `data` table instead of the vehicle (`data.vehicle` is the entity). New hooks: `Editable.Server.DispatchAlert`, `Editable.Server.GiveVehicleKeys`, `Editable.Server.RemoveVehicleKeys`, `Editable.Inventory`.
- **Dependencies:** `oxmysql` is now required. `ox_inventory` is no longer required.
- **Exports:** the client export is `exports.nek_chopshop:GetJobStatus()` (use the real resource folder name); new server exports `GetReputation` and `AddReputation`.

Back up your `shared/config.lua` and `editable/` files before replacing the resource, then re-apply your changes on top of the new files. Full list of changes: [CHANGELOG.md](CHANGELOG.md).

## Documentation in other languages

- [Español](docs/i18n/README.es.md)
- [Português (Brasil)](docs/i18n/README.pt-br.md)
- [Français](docs/i18n/README.fr.md)
- [Deutsch](docs/i18n/README.de.md)

## License

See [LICENSE](LICENSE).
