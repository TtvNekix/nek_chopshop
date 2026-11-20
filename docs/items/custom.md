# Custom inventory — nek_chopshop

For inventories without a built-in adapter (codem-inventory, tgiann-inventory, origen_inventory, ...).

1. Set `Config.Inventory = 'custom'` in `shared/config.lua`.
2. Open `editable/server.lua` and fill the functions of `Editable.Inventory` with your inventory's **server** exports. Each one has a commented example.
3. Register the 11 items in your inventory (use the block of the closest format: [`ox_inventory.md`](ox_inventory.md) for ox-style item lists, [`qb-inventory.md`](qb-inventory.md) for QBCore-style lists) and copy the images from `[assets]`.

| Function | Must return |
| --- | --- |
| `AddItem(src, item, count, metadata)` | `true` when the items were given. |
| `RemoveStack(src, item, count, stack)` | `true` only when exactly `count` was removed from `stack` (`{ slot, count, metadata }` from `GetStacks`). |
| `GetCount(src, item)` | Total amount held. |
| `GetStacks(src, item)` | `{ { slot = number, count = number, metadata = table|nil }, ... }` |
| `CanCarry(src, grants)` | `true` when every grant (`{ item, count, metadata }`) fits at once. |
| `ItemExists(item)` (optional) | `true`/`false`, or `nil` when unknown (the start check is skipped). |
| `MakeMetadata(quality, description)` (optional) | The metadata given to part items. Default `{ chopQuality = quality, description = description }`. |
| `ExactStacks` | `true` only if `RemoveStack` removes from that exact slot. |
| `ItemResources` | Resources whose restart re-runs the item check. |

Rules:

- **Do not wait or await** inside these functions. The server checks space and gives the items with no yield in between, and the sell ped reads and removes stacks with no yield in between.
- A missing function fails closed (nothing given, removed or sold) and prints a one-time console warning.
- The tier quality is read from `metadata.chopQuality` (or `metadata.quality` when it is a string).

## Known limitations

- With `ExactStacks = false` (default) selling by quality is degraded like core_inventory: a player holding one item in several qualities is paid the lowest of them for all. Set `ExactStacks = true` once `RemoveStack` removes by slot.
