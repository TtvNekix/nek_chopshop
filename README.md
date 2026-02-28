# Nekix ChopShop

Advanced Chop Shop system for FiveM, supporting ESX and QBCore.

## Features
- **Multi-Framework:** Works with ESX and QBCore out of the box.
- **Highly Configurable:** Customize everything from vehicles, locations, payouts, and cooldowns.
- **Ox Lib & Target:** Uses the latest `ox_lib` and `ox_target` for optimal performance and interaction.
- **Partner System:** Players can designate a partner to share the job (synced progress/completion).
- **Lockpick Minigame:** Integrated minigame for stealing vehicles (customizable).
- **Discord Logs:** Full logging for job start, items received, payments, and warnings.
- **Cooldown System:** prevents spamming jobs (configurable duration).

## Installation

1. ensure `ox_lib`, `ox_target`, and `ox_inventory` are installed and started.
2. Put the `chopshop` folder in your resources directory.
3. Configure `shared/config.lua` to match your server needs (Framework, Locales, etc.).
4. Add `ensure chopshop` to your `server.cfg`.

## Configuration (`shared/config.lua`)

| Config Option | Description |
| :--- | :--- |
| `Config.Framework` | Set to `'esx'` or `'qbcore'`. |
| `Config.Debug` | Enable debug prints. |
| `Config.Ped` | Configuration for the NPC ped (model, coords, etc.). |
| `Config.Discord` | Webhook settings (Name, Avatar, Colors). **Webhook URL is in `editable/server.lua`**. |
| `Config.Logs` | Toggle specific log types (Items, Pay, Finish). |
| `Config.Payment` | Enable payments and set Min/Max reward amounts. |
| `Config.Cooldown` | Cooldown duration in seconds (Default: 3600s / 1 hour). |
| `Config.Locales` | Translate all in-game text here. |

## Refund & Editability
- **Core Logic:** The core logic is structured in `server/main.lua` and `client/main.lua`.
- **Editable Functions:**  
    - `editable/client.lua`: Customize Minigames, Alerts, and Notifications.
    - `editable/server.lua`: **Set your Discord Webhook here**. Customize logging logic or add custom rewards.

## Exports

### Client
```lua
-- Get the current job status (if needed for external UIs)
exports.chopshop:GetJobStatus() 
```

## Dependencies
- ox_lib
- ox_target
- ox_inventory
- es_extended OR qb-core

## Ox Inventory Implementation

Add the following items to your `ox_inventory/data/items.lua`:

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
```

## Icons
Images for these items can be found in the `[assets]` folder. Drag and drop them into your inventory images directory.