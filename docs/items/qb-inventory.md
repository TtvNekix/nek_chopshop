# qb-inventory — nek_chopshop items

QBCore only (Qbox uses ox_inventory). Copy the block below into `qb-core/shared/items.lua` (inside `QBShared.Items = { ... }`) and restart the server.

```lua
vehicle_door      = { name = 'vehicle_door', label = 'Vehicle Door', weight = 2000, type = 'item', image = 'vehicle_door.png', unique = true, useable = false, shouldClose = true, description = 'A removed vehicle door.' },
vehicle_hood      = { name = 'vehicle_hood', label = 'Vehicle Hood', weight = 3000, type = 'item', image = 'vehicle_hood.png', unique = true, useable = false, shouldClose = true, description = 'A removed vehicle hood.' },
veh_wheels        = { name = 'veh_wheels', label = 'Vehicle Wheel', weight = 5000, type = 'item', image = 'veh_wheels.png', unique = true, useable = false, shouldClose = true, description = 'A vehicle wheel.' },
veh_suspension    = { name = 'veh_suspension', label = 'Vehicle Suspension', weight = 4000, type = 'item', image = 'veh_suspension.png', unique = true, useable = false, shouldClose = true, description = 'Vehicle suspension parts.' },
['car-battery']   = { name = 'car-battery', label = 'Car Battery', weight = 1000, type = 'item', image = 'car-battery.png', unique = false, useable = false, shouldClose = true, description = 'A standard car battery.' },
vehicle_trunk     = { name = 'vehicle_trunk', label = 'Vehicle Trunk', weight = 3000, type = 'item', image = 'vehicle_trunk.png', unique = true, useable = false, shouldClose = true, description = 'A removed vehicle trunk lid.' },
vehicle_engine    = { name = 'vehicle_engine', label = 'Vehicle Engine', weight = 8000, type = 'item', image = 'vehicle_engine.png', unique = true, useable = false, shouldClose = true, description = 'A removed vehicle engine.' },
vehicle_seat      = { name = 'vehicle_seat', label = 'Vehicle Seat', weight = 2500, type = 'item', image = 'vehicle_seat.png', unique = true, useable = false, shouldClose = true, description = 'A removed vehicle seat.' },
-- Loot-only items (Config.Tiers[].loot)
scrap_metal       = { name = 'scrap_metal', label = 'Scrap Metal', weight = 500, type = 'item', image = 'scrap_metal.png', unique = false, useable = false, shouldClose = true, description = 'Scrap metal from a stripped vehicle.' },
sport_wheel       = { name = 'sport_wheel', label = 'Sport Wheel', weight = 6000, type = 'item', image = 'sport_wheel.png', unique = true, useable = false, shouldClose = true, description = 'A lightweight sport wheel.' },
turbo_kit         = { name = 'turbo_kit', label = 'Turbo Kit', weight = 4000, type = 'item', image = 'turbo_kit.png', unique = true, useable = false, shouldClose = true, description = 'A turbocharger kit pulled from a fast engine.' },
```

`unique = true` means the item never stacks (one per slot), like `stack = false` in ox_inventory.

## Images

Copy every `.png` from this resource's `[assets]` folder into `qb-inventory/html/images/`.
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
nek_chopshop does not use `info.quality` here, because QB-family inventories use that field as a number for item durability.
The parts buyer pays each stack according to `Config.SellPed.QualityMultiplier`.

## Known limitations

- **Selling by quality is degraded.** qb-inventory stacks items by name and probably ignores `info`, so parts of different qualities can merge into one stack. nek_chopshop therefore treats it as not exact: when a player holds the same item in several stacks, every stack of that item is priced at the **lowest** quality held (and a failed payment gives that lowest quality back). Items of one quality are paid normally.
- Stackable items (`car-battery`, `scrap_metal`) given with different qualities are kept apart by nek_chopshop's space check (it always reserves a free slot for them), which can refuse a part a little earlier than strictly needed when the inventory is almost full.

## Checking your setup

On start (and whenever qb-inventory or qb-core restarts) nek_chopshop checks every configured part, bonus, finish reward and loot item.
If you see `... is not registered in qb-inventory` in the server console, the item is missing from the item list above.
