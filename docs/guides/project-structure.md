---
sidebar_position: 1
title: Project structure
description: Where KeepData boots, how modules share paths, and client/server layout.
---

# Recommended project structure

```
ReplicatedStorage
  Packages/              ← wally install (dataservicev2)
  DataTemplate.luau      ← export type Schema = typeof(Data)
  Shared/
    EconomyConstants.luau

ServerScriptService
  KeepDataServer.server.luau    ← CreateStore, leaderboards, BindToClose
  Services/
    InventoryService.luau
    LeaderboardRewards.luau

StarterPlayerScripts
  KeepDataClient.client.luau    ← Init({ StoreNames })
  Controllers/
    InventoryUI.client.luau
    LeaderboardUI.client.luau
```

## Bootstrap scripts

**One** server script owns KeepData initialization:

- `CreateStore` for player data (and optional guild/clan stores).
- `game:BindToClose` → `KeepData.Server:FlushAll()`.
- `PlayerAdded` → `Store:WaitFor` → wire gameplay services.

**One** client script calls `Client:Init` with every replicated store name before UI controllers run.

## Sharing logic

| Layer | Responsibility |
| --- | --- |
| `DataTemplate` | Default values + `Schema` type |
| `Services/*` (server) | Mutations, validation, economy rules |
| `Controllers/*` (client) | Read paths, connect signals, never `Set` |
| `Shared` | Item ids, constants — no KeepData require required |

Pass `PlayerStore` or `Paths` into services during `init()` to avoid circular requires.

## Multi-store games

```lua
-- Server
local PlayerStore = KeepData.Server.CreateStore(PlayerTemplate, "PlayerData")
local GuildStore = KeepData.Server.CreateStore(GuildTemplate, "GuildData")

-- Client
KeepData.Client:Init({ StoreNames = { "PlayerData", "GuildData" } })
```

Guild data keys use `GuildStore` options (`KeyPrefix`, etc.) — see [Stores and platform](./stores-and-platform).

## Examples in this repo

- [Inventory system](./inventory-system)
- [Leaderboard system](./leaderboard-system)
