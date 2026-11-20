# Changelog

All notable changes to nek_chopshop are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [2.0.0]

### Added

- **Qbox support** and framework auto-detection: `Config.Framework = 'auto'` (default) picks `qbx_core` > `es_extended` > `qb-core`. A forced framework that is not started falls back to auto-detection with a console warning.
- **Inventory bridge:** ox_inventory, qs-inventory, core_inventory, ps-inventory and qb-inventory (`Config.Inventory`, auto-detected), plus a `custom` adapter (`Editable.Inventory`). ox_inventory is no longer a hard dependency.
- **Item guides** for every inventory in `docs/items/` (copy-paste blocks), item images in `[assets]`, and a start-up check that reports unregistered items.
- **Vehicle keys bridge** (`Config.VehicleKeys`): the job owner receives the keys of the job vehicle after the server validates the lockpick. Supports `qbx_vehiclekeys`, `qs-vehiclekeys`, `wasabi_carlock`, `MrNewbVehicleKeys`, `ak47_vehiclekeys`, `vehicles_keys`, `qb-vehiclekeys`, `custom` (`Editable.Server.GiveVehicleKeys` / `RemoveVehicleKeys`) or off. Keys are removed when the job ends.
- **Police minimum and dispatch bridge** (`Config.Police`): minimum officers on duty per framework, optional per-tier `minPolice`, and a server-driven alert for `ps-dispatch`, `cd_dispatch`, `qs-dispatch`, `rcore_dispatch`, `core_dispatch`, `tk_dispatch`, `origen_police`, `lb-tablet`, `linden_outlawalert`, `custom` or off.
- **Locales through ox_lib** in 10 languages: en, es, fr, de, it, pt-br, pl, nl, tr, cs (`locales/*.json`, language set with `setr ox:locale`).
- **Persistent job cooldown** stored in the resource KVP (per character and per license), and the admin command `chopshop_resetcd <all|id>` with `Config.AdminAce`.
- **Time limits** (`Config.TimeLimit`): pickup and scrap timers; an expired job is cancelled and its scrapyard bay released.
- **Reputation** (`Config.Reputation`): per-character XP and levels in oxmysql (`nek_chopshop_reputation`, created automatically), level perks (sell price, shorter cooldown, extra part chance), optional weekly decay, job board block, level-up notification and Discord log.
- **Vehicle tiers and loot** (`Config.Tiers`): low / mid / high vehicle tiers chosen by weight and reputation level, per-tier payout, item quality (`standard`, `premium`, `exotic`) and server-rolled loot tables (`scrap_metal`, `sport_wheel`, `turbo_kit`).
- **Per-stack selling by quality** (`Config.SellPed.QualityMultiplier`) combined with the reputation sell multiplier.
- **More parts:** trunk, engine and front seats, with server-enforced `requires` (engine needs the hood, seats need their door). Only the 4 wheels are mandatory; the other parts are optional per vehicle model.
- **Partner invite before scrapping:** the owner invites a partner before starting to strip; the partner has to accept and joins the scrap when it starts. The partner receives a share of the XP.
- **Work-order NUI:** job board, job slip with in-sheet notes, loose notes, partner invite and parts buyer, with smooth slide-in and slide-out animations. `Config.UseNUI = false` falls back to ox_lib menus. `/chopshopui` releases a stuck mouse focus. The page contract is in `web/CONTRACT.md`.
- **Server exports** `GetReputation(identifier)` and `AddReputation(identifier, amount, reason)`.
- **Editable hooks:** `Editable.Server.DispatchAlert`, `GiveVehicleKeys`, `RemoveVehicleKeys` and `Editable.Inventory`.
- **Documentation:** rewritten README, this changelog and installation guides in Spanish, Brazilian Portuguese, French and German (`docs/i18n/`).

### Changed

- The vehicle model, tier and parts are chosen by the server; `Config.Vehicles` is replaced by `Config.Tiers` (the old flat list still works as a single `low` tier).
- `Editable.Client.DispatchAlert` receives a `data` table instead of the vehicle (`data.vehicle` is the entity).
- `Config.Locales` was removed; texts moved to `locales/*.json`.
- `oxmysql` is now required (no query runs while `Config.Reputation.Enabled = false`).
- Rejections now state the real reason (cooldown, police, no free bay, anti-teleport wait time) instead of a generic error.
- Ped targets survive entity streaming (no duplicated or lost options).
- Item image `vehicle_wheel.png` renamed to `veh_wheels.png`.
- Part removal no longer shows a "stripped" notification for every part.
- Client export `GetJobStatus` fixed and documented; version checker compares versions numerically per segment (`1.10` is newer than `1.9`).

### Fixed

- Vehicle physics: the car now drops to the ground when its wheels are removed (the server unfreezes the vehicle when scrapping starts and the network owner reactivates its physics).
- Scrapyard bays locked forever when a player disconnected.
- Shared `quantity` counter between jobs, plate collisions between jobs and duplicated ox_target options on the ped.
- A job could be left unfinishable on a vehicle model that lacks one of the removable bones.
- Cooldown lost on restart or bypassed by changing character.

### Security

- Server-authoritative jobs: the server picks the vehicle and spawn point, owns the job state and decides every item, payment and XP. Client events and callbacks cannot grant items, money or XP.
- Server-side checks on every action: distance to the ped, sell ped, vehicle and scrap point, minimum time between part removals, partner consent, lockpick item held, job stage, plate and entity identity.
- Anti-teleport delivery check (`Config.Security.MaxAverageSpeed`); players with `Config.AdminAce` skip it so staff can test.
- Inventory space (slots and weight) is checked before a part and its loot are given; nothing is given if it does not fit.
- Sell ped validates distance and the items held, and rolls back exactly on failure.
- Throttled warning logs (`Config.Security.WarnThrottle`) to prevent webhook flooding.
- Arguments of every callback and event are type-checked and bounded.

## [1.0.0]

- Initial release: ESX chop shop job with partner system, lockpick minigame, sell ped, Discord logs and ox_inventory support.
