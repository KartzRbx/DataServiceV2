---
sidebar_position: 5
title: Example — global leaderboard
description: OrderedDataStore leaderboard wired to KeepData paths, server sync, and client UI.
---

# Example: global coin leaderboard

This pattern fits **persistent stats** (total coins earned, trophies, XP) that should appear on a global top-100 board and update clients with **delta** or **full** sync.

## Template field

Use a monotonic stat — not spendable balance — so purchases do not drop players on the board incorrectly.

```lua
Stats = {
	TotalCoinsEarned = 0,
},
```

## Server setup

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local DataTemplate = require(ReplicatedStorage.DataTemplate)
local KeepData = require(ReplicatedStorage.Packages.keepdata)

local PlayerStore = KeepData.Server.CreateStore(DataTemplate, "PlayerData", {
	UseMock = RunService:IsStudio(), -- optional Studio mock
})

local Paths = PlayerStore.Paths

local TopCoins = PlayerStore:CreateLeaderboard({
	Name = "TopCoins",
	Key = Paths.Stats.TotalCoinsEarned,
	UpdateInterval = 45,
	MaxItems = 100,
	SyncMode = "delta",
	AutoSync = true,
})

-- Push scores to OrderedDataStore when the stat changes
local function bindLeaderboardSync(player: Player, handle)
	local userId = player.UserId
	handle:Watch(Paths.Stats.TotalCoinsEarned, function(newTotal)
		if type(newTotal) == "number" then
			TopCoins:_postPlayerScore(userId, newTotal)
		end
	end)
	-- Initial score after load
	local current = handle:Get(Paths.Stats.TotalCoinsEarned)
	if type(current) == "number" then
		TopCoins:_postPlayerScore(userId, current)
	end
end

Players.PlayerAdded:Connect(function(player)
	local handle = PlayerStore:WaitFor(player)
	bindLeaderboardSync(player, handle)
end)

TopCoins.RankChanged:Connect(function(change)
	print(`User {change.UserId} rank {change.OldRank} -> {change.NewRank}`)
end)

game:BindToClose(function()
	KeepData.Server:FlushAll()
end)
```

**Note:** ODS writes also run on player leave and `FlushAll`. The `Watch` + `_postPlayerScore` hook keeps the board fresh while players are online.

## Awarding score (gameplay)

```lua
local function awardCoins(player: Player, amount: number)
	local handle = PlayerStore:WaitFor(player)
	handle:Update(Paths.Currencies.Coins, function(c)
		return (c or 0) + amount
	end)
	handle:Update(Paths.Stats.TotalCoinsEarned, function(total)
		return (total or 0) + amount
	end)
end
```

## Client UI (ScreenGui)

```lua
local KeepData = require(ReplicatedStorage.Packages.keepdata)

KeepData.Client:Init({ StoreNames = { "PlayerData" } })

local board = KeepData.Client:GetLeaderboard("TopCoins")

local function render(entries)
	for i, entry in entries do
		-- entry.Rank, entry.UserId, entry.Value
	end
end

render(board:Get())

board:OnUpdate(function(entries)
	render(entries)
end)

board:OnRankChanged(function(change)
	if change.UserId == game.Players.LocalPlayer.UserId then
		print("Your rank:", change.NewRank)
	end
end)
```

## Modes

| `SyncMode` | Behavior |
| --- | --- |
| `"delta"` | Clients receive rank change payloads; lighter for large boards |
| `"full"` | Full top list broadcast each refresh |

| `AutoSync` | When `true`, refresh cycles broadcast to clients after ODS read |

## Studio / testing

Set `UseMock = true` on the **store** so leaderboard ODS uses `Mock_{StoreName}/{Name}` and avoids live DataStore in Studio.

## Related APIs

- [Stores and platform](./stores-and-platform)
- [API reference — Leaderboards](../api-reference#leaderboards)
