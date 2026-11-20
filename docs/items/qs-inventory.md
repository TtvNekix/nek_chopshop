# qs-inventory — nek_chopshop items

Works with ESX, QBCore and Qbox. Copy the block below into qs-inventory's item list and restart the server:

- **qs-inventory item file:** `qs-inventory/shared/items.lua` (UNVERIFIED path: check the qs-inventory documentation of your version; some versions read the items from `qb-core/shared/items.lua` on QBCore).
- **QBCore with the items in qb-core:** use the block from [`qb-inventory.md`](qb-inventory.md) in `qb-core/shared/items.lua` instead.

```lua
['vehicle_door'] = {
    ['name'] = 'vehicle_door',
    ['label'] = 'Vehicle Door',
    ['weight'] = 2000,
    ['type'] = 'item',
    ['image'] = 'vehicle_door.png',
    ['unique'] = true,
    ['useable'] = false,
    ['shouldClose'] = true,
    ['description'] = 'A removed vehicle door.'
},
['vehicle_hood'] = {
    ['name'] = 'vehicle_hood',
    ['label'] = 'Vehicle Hood',
    ['weight'] = 3000,
    ['type'] = 'item',
    ['image'] = 'vehicle_hood.png',
    ['unique'] = true,
    ['useable'] = false,
    ['shouldClose'] = true,
    ['description'] = 'A removed vehicle hood.'
},
['veh_wheels'] = {
    ['name'] = 'veh_wheels',
    ['label'] = 'Vehicle Wheel',
    ['weight'] = 5000,
    ['type'] = 'item',
    ['image'] = 'veh_wheels.png',
    ['unique'] = true,
    ['useable'] = false,
    ['shouldClose'] = true,
    ['description'] = 'A vehicle wheel.'
},
['veh_suspension'] = {
    ['name'] = 'veh_suspension',
    ['label'] = 'Vehicle Suspension',
    ['weight'] = 4000,
    ['type'] = 'item',
    ['image'] = 'veh_suspension.png',
    ['unique'] = true,
    ['useable'] = false,
    ['shouldClose'] = true,
    ['description'] = 'Vehicle suspension parts.'
},
['car-battery'] = {
    ['name'] = 'car-battery',
    ['label'] = 'Car Battery',
    ['weight'] = 1000,
    ['type'] = 'item',
    ['image'] = 'car-battery.png',
    ['unique'] = false,
    ['useable'] = false,
    ['shouldClose'] = true,
    ['description'] = 'A standard car battery.'
},
['vehicle_trunk'] = {
    ['name'] = 'vehicle_trunk',
    ['label'] = 'Vehicle Trunk',
    ['weight'] = 3000,
    ['type'] = 'item',
    ['image'] = 'vehicle_trunk.png',
    ['unique'] = true,
    ['useable'] = false,
    ['shouldClose'] = true,
    ['description'] = 'A removed vehicle trunk lid.'
},
['vehicle_engine'] = {
    ['name'] = 'vehicle_engine',
    ['label'] = 'Vehicle Engine',
    ['weight'] = 8000,
    ['type'] = 'item',
    ['image'] = 'vehicle_engine.png',
    ['unique'] = true,
    ['useable'] = false,
    ['shouldClose'] = true,
    ['description'] = 'A removed vehicle engine.'
},
['vehicle_seat'] = {
    ['name'] = 'vehicle_seat',
    ['label'] = 'Vehicle Seat',
    ['weight'] = 2500,
    ['type'] = 'item',
    ['image'] = 'vehicle_seat.png',
    ['unique'] = true,
    ['useable'] = false,
    ['shouldClose'] = true,
    ['description'] = 'A removed vehicle seat.'
},
-- Loot-only items (Config.Tiers[].loot)
['scrap_metal'] = {
    ['name'] = 'scrap_metal',
    ['label'] = 'Scrap Metal',
    ['weight'] = 500,
    ['type'] = 'item',
    ['image'] = 'scrap_metal.png',
    ['unique'] = false,
    ['useable'] = false,
    ['shouldClose'] = true,
    ['description'] = 'Scrap metal from a stripped vehicle.'
},
['sport_wheel'] = {
    ['name'] = 'sport_wheel',
    ['label'] = 'Sport Wheel',
    ['weight'] = 6000,
    ['type'] = 'item',
    ['image'] = 'sport_wheel.png',
    ['unique'] = true,
    ['useable'] = false,
    ['shouldClose'] = true,
    ['description'] = 'A lightweight sport wheel.'
},
['turbo_kit'] = {
    ['name'] = 'turbo_kit',
    ['label'] = 'Turbo Kit',
    ['weight'] = 4000,
    ['type'] = 'item',
    ['image'] = 'turbo_kit.png',
    ['unique'] = true,
    ['useable'] = false,
    ['shouldClose'] = true,
    ['description'] = 'A turbocharger kit pulled from a fast engine.'
},
```

`unique = true` means the item never stacks (one per slot), like `stack = false` in ox_inventory.

## Images

Copy every `.png` from this resource's `[assets]` folder into `qs-inventory/html/images/` (UNVERIFIED folder: check your qs-inventory version).
Each file is already named after its item, matching the `image` field above.

| Item | Image |
| --- | --- |
| `vehicle_door` | `[assets]/vehicle_door.png` |
| `vehicle_hood` | `[assets]/vehicle_hood.png` |
| `veh_wheels` | `[assets]/veh_wheels.png` |
| `veh_suspension` | `[assets]/veh_suspension.png` |
| `car-battery` | `[assets]/car-battery.png` |
| `vehicle_trunk` | `[assets]/vehicle_trunk.png` |
| `vehicle_engine` | `[assets]/vehicle_engine.png` |
| `vehicle_seat` | `[assets]/vehicle_seat.png` |
| `scrap_metal` | `[assets]/scrap_metal.png` |
| `sport_wheel` | `[assets]/sport_wheel.png` |
| `turbo_kit` | `[assets]/turbo_kit.png` |

## Quality metadata

Part items carry the tier quality in the item info as `chopQuality` (`standard`, `premium` or `exotic`) plus a `description`.
nek_chopshop does not use `info.quality` here, because qs-inventory uses quality as item durability.
The parts buyer pays each stack according to `Config.SellPed.QualityMultiplier`.

## Known limitations

- The adapter is written from the qs-inventory documentation (not tested against the paid source). The `RemoveItem` result is checked by comparing the item count before and after, and `GetItemsByName` fields are read as `amount`/`count` and `info`/`metadata`.
- The space check uses `CanCarryItems`, which does not look at metadata.
- **Selling by quality is degraded.** Whether qs-inventory keeps items with different `info` apart is unverified, so nek_chopshop treats it as not exact: when a player holds the same item in several stacks, every stack of that item is priced at the **lowest** quality held (and a failed payment gives that lowest quality back). Items of one quality are paid normally.
- `AddItem` returns nothing on a refusal, so a failed add cannot be told from a successful one with no return value. If giving a part reports a failure, the part stays removed (it is never re-opened) and the player is told there is no space; check the server console.
- Entries returned by `GetItemsByName` without an explicit `slot` are ignored, and so are entries whose `name` differs from the requested item.

## Checking your setup

On start (and whenever qs-inventory restarts) nek_chopshop checks every configured part, bonus, finish reward and loot item.
If you see `... is not registered in qs-inventory` in the server console, the item is missing from the item list above.
If the item list cannot be read, the check is skipped.
