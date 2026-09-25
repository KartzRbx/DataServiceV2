---
title: Getting started
description: Install KeepData (Wally kartzrbx/keepdata), define a template, and boot server + client.
sidebar_position: 1
---

# Getting started with KeepData

**KeepData** (Wally package `kartzrbx/keepdata`, v1+) is a Roblox data layer: **ProfileStore** persistence, **QuickNet** replication, **typed path tokens**, optional **multi-store** replication, **OrderedDataStore leaderboards**, migrations, policy hooks, and session-only fields.

In code you still `require(ReplicatedStorage.Packages.keepdata)` — the folder name comes from Wally. Treat the API as **KeepData** in docs and game architecture.

Bundled dependencies (`signal`, `quicknet`, `janitor`) ship inside the package. You do **not** add them to your game's `wally.toml`.

## 1) Install

```toml
[dependencies]
keepdata = "kartzrbx/keepdata@1.0.0"
```

```bash
wally install
```

Rojo — map `Packages` into `ReplicatedStorage`:

```json
{
  "name": "MyGame",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Packages": { "$path": "Packages" },
      "DataTemplate": { "$path": "src/DataTemplate.luau" }
    }
  }
}
```

## 2) Data template

Keep values JSON-serializable (numbers, strings, booleans, arrays, plain tables).

```lua
-- ReplicatedStorage/DataTemplate.luau
local Data = {
	Currencies = {
		Coins = 0,
		Gems = 0,
	},
	Stats = {
		Level = 1,
		XP = 0,
		TotalCoinsEarned = 0,
	},
	Inventory = {
		Items = {} :: { { Id = "", Count = 0 } },
		MaxSlots = 24,
	},
	Settings = {
		MusicVolume = 0.8,
	},
}

export type Schema = typeof(Data)

return Data
```

Optional codegen scaffold:

```bash
npm run dataservice:generate
```

## 3) Server bootstrap (recommended: `CreateStore`)

`CreateStore` is the v3 entry point: typed `Store.Paths`, `ServerDataHandle` (`Set`, `Patch`, `Watch`), leaderboards, migrations, and policy — without casting `Paths` to `Schema`.

```lua
-- ServerScriptService/KeepDataServer.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataTemplate = require(ReplicatedStorage.DataTemplate)
local KeepData = require(ReplicatedStorage.Packages.keepdata)

local PlayerStore = KeepData.Server.CreateStore(DataTemplate, "PlayerData", {
	StrictPaths = true,
	TemplateVersion = 1,
	UseMock = false, -- true in Studio without DataStore access
})

local Paths = PlayerStore.Paths

Players.PlayerAdded:Connect(function(player)
	local handle = PlayerStore:WaitFor(player)
	handle:Set(Paths.Currencies.Coins, 100)
end)
```

Legacy one-liner (still supported):

```lua
KeepData.Server:Init({
	Template = DataTemplate,
	StoreName = "PlayerData",
	StrictPaths = true,
})
```

## 4) Client bootstrap

Register every **replicated** store name before packets arrive:

```lua
-- StarterPlayerScripts/KeepDataClient.client.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeepData = require(ReplicatedStorage.Packages.keepdata)

local data = KeepData.Client:Init({ StoreNames = { "PlayerData" } })
local Paths = KeepData.Client.Paths

print("Coins:", data:Get(Paths.Currencies.Coins))

data:GetChangedSignal(Paths.Currencies.Coins):Connect(function(newValue, oldValue)
	print("Coins:", oldValue, "->", newValue)
end)
```

## 5) Mutate on the server only

```lua
local handle = PlayerStore:WaitFor(player)
local Paths = PlayerStore.Paths

handle:Update(Paths.Currencies.Coins, function(current)
	return (current or 0) + 50
end)

handle:Patch({
	Stats = { XP = handle:Get(Paths.Stats.XP) + 10 },
})
```

Clients mirror data through QuickNet; never call `Set` / `Update` on the client.

## What KeepData gives you

| Capability | Where to learn more |
| --- | --- |
| Typed paths (`Store.Paths.Currencies.Coins`) | [Typed paths](./guides/paths) |
| Inventory-style lists and patches | [Inventory system](./guides/inventory-system) |
| Global leaderboards (ODS + client UI) | [Leaderboard system](./guides/leaderboard-system) |
| Stores, migrations, policy, session data | [Stores & platform](./guides/stores-and-platform) |
| Admin preview without saving | [Transient overlay](./guides/transient) |
| Sorting backpack / quest lists | [Ordered lists](./guides/ordered-lists) |
| Full method list | [API reference](./api-reference) |

## Local test sandbox

```powershell
.\scripts\setup-test-env.ps1
cd Test
rojo serve
```

## Next steps

- [Recommended project structure](./guides/project-structure)
- [Example: leaderboard](./guides/leaderboard-system)
- [Example: inventory](./guides/inventory-system)
