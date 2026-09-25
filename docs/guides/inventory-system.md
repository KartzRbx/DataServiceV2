---
sidebar_position: 6
title: Example — inventory system
description: Stackable items, server authority, client UI, and ordered list queries.
---

# Example: stackable inventory

KeepData keeps **inventory authoritative on the server**. Clients read replicated `Inventory.Items` and react with `GetChangedSignal` for UI refresh.

## Template

```lua
Inventory = {
	Items = {} :: { { Id = string, Count = number } },
	MaxSlots = 24,
},
```

`Id` is your item definition key (`"IronOre"`, `"HealthPotion"`). Store **instances** as rows `{ Id, Count }` for stackables.

## Server — InventoryService module

```lua
-- ServerScriptService/Services/InventoryService.luau
local InventoryService = {}
InventoryService._store = nil
InventoryService._paths = nil

function InventoryService.init(playerStore)
	InventoryService._store = playerStore
	InventoryService._paths = playerStore.Paths
end

local function findStack(items, itemId)
	for index, row in items do
		if row.Id == itemId then
			return index, row
		end
	end
	return nil
end

function InventoryService.addItem(player: Player, itemId: string, amount: number)
	assert(amount > 0)
	local handle = InventoryService._store:WaitFor(player)
	local Paths = InventoryService._paths
	local items = handle:Get(Paths.Inventory.Items)

	local index, row = findStack(items, itemId)
	if row then
		handle:Update(Paths.Inventory.Items, function(list)
			local copy = table.clone(list)
			copy[index].Count += amount
			return copy
		end)
	else
		if #items >= handle:Get(Paths.Inventory.MaxSlots) then
			return false, "full"
		end
		handle:Update(Paths.Inventory.Items, function(list)
			local copy = table.clone(list)
			table.insert(copy, { Id = itemId, Count = amount })
			return copy
		end)
	end
	return true
end

function InventoryService.removeItem(player: Player, itemId: string, amount: number)
	local handle = InventoryService._store:WaitFor(player)
	local Paths = InventoryService._paths
	local index, row = findStack(handle:Get(Paths.Inventory.Items), itemId)
	if not row or row.Count < amount then
		return false
	end
	handle:Update(Paths.Inventory.Items, function(list)
		local copy = table.clone(list)
		if copy[index].Count == amount then
			table.remove(copy, index)
		else
			copy[index].Count -= amount
		end
		return copy
	end)
	return true
end

return InventoryService
```

Bootstrap:

```lua
local PlayerStore = KeepData.Server.CreateStore(DataTemplate, "PlayerData")
require(ServerScriptService.Services.InventoryService).init(PlayerStore)
```

## RemoteEvent boundary (recommended)

Never trust the client with `Set`. Expose one RemoteFunction:

```lua
GiveItemRemote.OnServerInvoke = function(player, itemId, amount)
	if type(itemId) ~= "string" or type(amount) ~= "number" then
		return false
	end
	return InventoryService.addItem(player, itemId, math.clamp(amount, 1, 999))
end
```

Combine with [Policy](./stores-and-platform) `CanMutate` if you mutate through generic admin tools.

## Client — backpack UI

```lua
local KeepData = require(ReplicatedStorage.Packages.dataservicev2)
local data = KeepData.Client:Init({ StoreNames = { "PlayerData" } })
local Paths = KeepData.Client.Paths

local function refresh()
	local items = data:Get(Paths.Inventory.Items)
	for _, row in items do
		-- row.Id, row.Count
	end
end

refresh()
data:GetChangedSignal(Paths.Inventory.Items):Connect(refresh)
```

## Sorting / “best item first” (server or client read)

Use ordered list helpers on dictionary-like tables, or sort the array in memory:

```lua
local Enum = KeepData.Enum
local sorted = data:GetOrderedListWithPriority(
	Paths.Inventory.Items,
	function(row) return row.Count end,
	Enum.OrderList.Desc
)
for _, entry in sorted do
	-- entry.index, entry.value, entry.priority
end
```

For array paths, `GetOrderedList` accepts options — see [Ordered lists](./ordered-lists).

## Partial updates with Patch

Grant a starter kit in one server call:

```lua
handle:Patch({
	Inventory = {
		Items = {
			{ Id = "StarterSword", Count = 1 },
			{ Id = "Bread", Count = 5 },
		},
	},
})
```

`Patch` merges nested tables through persisted `Set` operations on the handle.

## Testing with transient overlay

Preview a full inventory in Studio without saving:

```lua
handle.Data:SetTransient(Paths.Inventory.Items, {
	{ Id = "DebugSword", Count = 1 },
})
-- Client sees it via Get(); ClearTransient before production tests end
```

See [Transient overlay](./transient).

## Checklist

| Rule | Why |
| --- | --- |
| Mutate only on server | ProfileStore + anti-exploit |
| Clone arrays in `Update` | Luau tables are references; in-place mutation may skip change detection |
| Cap stack size in one place | Avoid duplicating limits in remotes and UI |
| Use `StrictPaths` in production | Typos fail fast at write time |
