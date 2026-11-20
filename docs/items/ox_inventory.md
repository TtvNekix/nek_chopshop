# ox_inventory — nek_chopshop items

Copy the block below into `ox_inventory/data/items.lua` (inside the returned table) and restart ox_inventory.

```lua
['vehicle_door'] = {
    label = 'Vehicle Door',
    weight = 2000,
    stack = false,
    close = true,
    description = 'A removed vehicle door.'
},
['vehicle_hood'] = {
    label = 'Vehicle Hood',
    weight = 3000,
    stack = false,
    close = true,
    description = 'A removed vehicle hood.'
},
['veh_wheels'] = {
    label = 'Vehicle Wheel',
    weight = 5000,
    stack = false,
    close = true,
    description = 'A vehicle wheel.'
},
['veh_suspension'] = {
    label = 'Vehicle Suspension',
    weight = 4000,
    stack = false,
    close = true,
    description = 'Vehicle suspension parts.'
},
['car-battery'] = {
    label = 'Car Battery',
    weight = 1000,
    stack = true,
    close = true,
    description = 'A standard car battery.'
},
['vehicle_trunk'] = {
    label = 'Vehicle Trunk',
    weight = 3000,
    stack = false,
    close = true,
    description = 'A removed vehicle trunk lid.'
},
['vehicle_engine'] = {
    label = 'Vehicle Engine',
    weight = 8000,
    stack = false,
    close = true,
    description = 'A removed vehicle engine.'
},
['vehicle_seat'] = {
    label = 'Vehicle Seat',
    weight = 2500,
    stack = false,
    close = true,
    description = 'A removed vehicle seat.'
},
-- Loot-only items (Config.Tiers[].loot)
['scrap_metal'] = {
    label = 'Scrap Metal',
    weight = 500,
    stack = true,
    close = true,
    description = 'Scrap metal from a stripped vehicle.'
},
['sport_wheel'] = {
    label = 'Sport Wheel',
    weight = 6000,
    stack = false,
    close = true,
    description = 'A lightweight sport wheel.'
},
['turbo_kit'] = {
    label = 'Turbo Kit',
    weight = 4000,
    stack = false,
    close = true,
    description = 'A turbocharger kit pulled from a fast engine.'
},
```

## Images

Copy every `.png` from this resource's `[assets]` folder into `ox_inventory/web/images/`.
Each file is already named after its item (`vehicle_door.png`, `veh_wheels.png`, ...), so ox_inventory picks them up automatically.

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

Icons come from the RAINMAD image gallery (https://items.rainmad.com/).

## Quality metadata

Part items carry a `quality` metadata (`standard`, `premium` or `exotic`) plus a description, so the quality shows in the item tooltip.
Items with different qualities do not stack together; the parts buyer pays each stack according to `Config.SellPed.QualityMultiplier`.

## Checking your setup

On start (and whenever ox_inventory restarts) nek_chopshop checks every configured part, bonus, finish reward and loot item.
If you see `... is not registered in ox_inventory` in the server console, the item is missing from `data/items.lua`.
