# core_inventory — nek_chopshop items

Works with Qbox, ESX and QBCore. Item format UNVERIFIED (written from the core_inventory documentation): compare with an existing item of your `core_inventory` before pasting.

## ox-style item list (`core_inventory/data/items.lua`)

`x` / `y` are the grid size of the item and `category` one of the categories configured in core_inventory.

```lua
['vehicle_door'] = {
    label = 'Vehicle Door',
    weight = 2000,
    stack = false,
    close = true,
    description = 'A removed vehicle door.',
    category = 'misc',
    x = 1,
    y = 1,
},
['vehicle_hood'] = {
    label = 'Vehicle Hood',
    weight = 3000,
    stack = false,
    close = true,
    description = 'A removed vehicle hood.',
    category = 'misc',
    x = 1,
    y = 1,
},
['veh_wheels'] = {
    label = 'Vehicle Wheel',
    weight = 5000,
    stack = false,
    close = true,
    description = 'A vehicle wheel.',
    category = 'misc',
    x = 2,
    y = 2,
},
['veh_suspension'] = {
    label = 'Vehicle Suspension',
    weight = 4000,
    stack = false,
    close = true,
    description = 'Vehicle suspension parts.',
    category = 'misc',
    x = 2,
    y = 2,
},
['car-battery'] = {
    label = 'Car Battery',
    weight = 1000,
    stack = true,
    close = true,
    description = 'A standard car battery.',
    category = 'misc',
    x = 1,
    y = 1,
},
['vehicle_trunk'] = {
    label = 'Vehicle Trunk',
    weight = 3000,
    stack = false,
    close = true,
    description = 'A removed vehicle trunk lid.',
    category = 'misc',
    x = 1,
    y = 1,
},
['vehicle_engine'] = {
    label = 'Vehicle Engine',
    weight = 8000,
    stack = false,
    close = true,
    description = 'A removed vehicle engine.',
    category = 'misc',
    x = 2,
    y = 2,
},
['vehicle_seat'] = {
    label = 'Vehicle Seat',
    weight = 2500,
    stack = false,
    close = true,
    description = 'A removed vehicle seat.',
    category = 'misc',
    x = 1,
    y = 1,
},
-- Loot-only items (Config.Tiers[].loot)
['scrap_metal'] = {
    label = 'Scrap Metal',
    weight = 500,
    stack = true,
    close = true,
    description = 'Scrap metal from a stripped vehicle.',
    category = 'misc',
    x = 1,
    y = 1,
},
['sport_wheel'] = {
    label = 'Sport Wheel',
    weight = 6000,
    stack = false,
    close = true,
    description = 'A lightweight sport wheel.',
    category = 'misc',
    x = 2,
    y = 2,
},
['turbo_kit'] = {
    label = 'Turbo Kit',
    weight = 4000,
    stack = false,
    close = true,
    description = 'A turbocharger kit pulled from a fast engine.',
    category = 'misc',
    x = 2,
    y = 2,
},
```

## QBCore / ESX

- **QBCore:** if your core_inventory reads the items from qb-core, use the block from [`qb-inventory.md`](qb-inventory.md) in `qb-core/shared/items.lua` (add `x`, `y` and `category` if your core_inventory version needs them).
- **ESX:** register the 11 items in your `items` database table (name, label, weight) or in core_inventory's own item list, as your core_inventory version requires.

## Images

Copy every `.png` from this resource's `[assets]` folder into core_inventory's image folder (UNVERIFIED: usually `core_inventory/html/img/`; check your version).

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

Part items carry the tier quality in the metadata as `chopQuality` (`standard`, `premium` or `exotic`) plus a `description`.

## Known limitations

- **Selling by quality is degraded.** core_inventory's `removeItem` has no slot or metadata parameter, so nek_chopshop cannot choose which stack is removed. When a player holds the same item with different qualities, every stack of that item is priced at the **lowest** quality held (and a failed payment gives that lowest quality back). Items of one quality are paid normally.
- The space check calls `canCarry` once per item: the combined weight of different items is not checked (core_inventory's `addItem` still refuses what does not fit).
- Add and remove results are checked by comparing the item count before and after (an add counts as done when the count rose by at least the amount given). If giving a part still reports a failure, the part stays removed (it is never re-opened) and the player is told there is no space; check the server console.
- There is no item list export, so the item check on start is skipped: make sure all 11 items exist.
