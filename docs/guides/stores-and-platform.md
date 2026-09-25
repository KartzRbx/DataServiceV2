---
sidebar_position: 2
title: Stores and platform features
description: CreateStore, multi-store replication, migrations, policy, session data, and shutdown.
---

# Stores and platform features

KeepData centers on **`DataStore<T>`** instances from `KeepData.Server.CreateStore`. Each store has its own ProfileStore name, path tree, optional replication, and leaderboards.

## CreateStore vs Init

| API | Use when |
| --- | --- |
| `Server.CreateStore(template, storeName, options?)` | New projects; multiple stores; leaderboards tied to a store |
| `Server:Init({ Template, StoreName, ... })` | Single store; same as creating the default store once |

```lua
local KeepData = require(ReplicatedStorage.Packages.keepdata)

local PlayerStore = KeepData.Server.CreateStore(DataTemplate, "PlayerData", {
	StrictPaths = true,
	ReplicateToClient = true,
})

local GuildStore = KeepData.Server.CreateStore(GuildTemplate, "GuildData", {
	ReplicateToClient = true,
	KeyPrefix = "Guild_",
})
```

Only stores with `ReplicateToClient = true` (default for the **first** store) sync to clients. The client must list every replicated name in `Client:Init({ StoreNames = { ... } })`.

## ServerDataHandle

`Store:WaitFor(player)` returns a handle — not the raw `Data` object, but it exposes `.Data` and `.Session`:

```lua
local handle = PlayerStore:WaitFor(player)
local Paths = PlayerStore.Paths

handle:Set(Paths.Currencies.Coins, 500)
handle:Patch({ Stats = { Level = 10 } })
handle:Watch(Paths.Stats.Level, function(level, prev)
	print("Level up", prev, "->", level)
end)

-- Underlying Data API still available:
handle.Data:GetChangedSignal(Paths.Currencies.Coins):Connect(function() end)
```

## Multi-store client

```lua
KeepData.Client:Init({ StoreNames = { "PlayerData", "GuildData" } })

local playerView = KeepData.Client:GetStore("PlayerData")
local guildView = KeepData.Client:GetStore("GuildData")

local coins = playerView.Data:Get(playerView.Paths.Currencies.Coins)
```

QuickNet packets include **`StoreId`** (your `StoreName`) so replication stays isolated per store.

## Migrations

Bump `TemplateVersion` and supply ordered migration steps. Version is stored on the profile at meta path `TemplateVersion` (default container key in saved data) unless you customize `MetaPath` in migrations.

```lua
local PlayerStore = KeepData.Server.CreateStore(DataTemplate, "PlayerData", {
	TemplateVersion = 3,
	Migrations = {
		{
			Version = 2,
			Up = function(data)
				data.Inventory = data.Inventory or { Items = {}, MaxSlots = 24 }
				return data
			},
		},
		{
			Version = 3,
			Up = function(data)
				data.Stats.TotalCoinsEarned = data.Stats.TotalCoinsEarned or 0
				return data
			},
		},
	},
})
```

Use `KeepData.Migration` helpers when you need shared utilities (see source `Migration.luau`).

## Policy (rate limits, ACL, audit)

```lua
Policy = {
	MutationsPerSecond = 40,
	CanMutate = function(player, action, path, newValue)
		if path[1] == "AdminFlags" then
			return false
		end
		return true
	end,
	Audit = function(entry)
		-- entry.Action, entry.Path, entry.Player, ...
	end,
	ValidateRuntimeTypes = true,
}
```

Failed checks block the mutation on the server before ProfileStore writes.

## Session data (never saved)

Per-player scratch space for match state, last zone, anti-AFK timers, etc.

```lua
handle.Session:Set({ MatchId = "abc", Streak = 3 })
local streak = handle.Session:Get().Streak
```

Session data does **not** replicate by default through the same paths as profile data — use it for server-side or explicitly synced gameplay state.

## Exclude secrets from clients

```lua
Exclude = {
	PlayerStore.Paths.AdminFlags,
},
```

Excluded paths are omitted from the initial snapshot and replication stream.

## Leaderboards (overview)

Leaderboards are created per store and backed by **OrderedDataStore** names `{StoreName}/{BoardName}`.

See the full walkthrough: [Leaderboard system](./leaderboard-system).

## Shutdown

On the server, `BindToClose` should flush ODS scores and end sessions:

```lua
game:BindToClose(function()
	KeepData.Server:FlushAll()
end)
```

`FlushAll` posts pending leaderboard scores and refreshes boards (see `Server.luau`).
