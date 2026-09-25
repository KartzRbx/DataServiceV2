---
sidebar_position: 3
title: Typed paths
description: Path tokens from your template — no manual path arrays, minimal casting.
---

# Typed paths

KeepData builds a **path tree** from your template. Tokens carry type information and work with `Set`, `Get`, signals, leaderboards, and `Exclude`.

## Store paths (recommended)

```lua
local KeepData = require(ReplicatedStorage.Packages.keepdata)
local DataTemplate = require(ReplicatedStorage.DataTemplate)

local PlayerStore = KeepData.Server.CreateStore(DataTemplate, "PlayerData")
local Paths = PlayerStore.Paths

local handle = PlayerStore:WaitFor(player)
handle:Set(Paths.Currencies.Coins, 100)

handle.Data:GetChangedSignal(Paths.Currencies.Coins):Connect(function(newValue, oldValue)
	print(newValue, oldValue)
end)
```

No `:: DataTemplate.Schema` cast is required when you use **`PlayerStore.Paths`** — Luau infers from the store generic.

## After `Server:Init`

If you use single-store `Init` instead of `CreateStore`, paths live on `KeepData.Server.Paths` and `KeepData.Paths` on the root export.

## Client

After `Client:Init`, use `KeepData.Client.Paths` or `GetStore(name).Paths`.

## Path module (advanced)

```lua
local Path = KeepData.Path
type Coins = Path.PathValue<typeof(PlayerStore.Paths.Currencies.Coins)>
```

`PathOf`, `PathToken`, and `createTemplatePaths` power the tree — useful for shared libraries and codegen.

## Rules

- Paths must exist on the template (unless `AutoCreateMissingTables` allows nested creation).
- With `StrictPaths = true`, invalid keys error at mutation time.
- `Exclude` uses the same tokens: `Exclude = { PlayerStore.Paths.ServerOnly }`.

See [Inventory example](./inventory-system) for array paths.
