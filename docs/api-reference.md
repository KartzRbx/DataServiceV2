---
title: API reference
description: KeepData (DataService v3) — Server, Client, Store, handles, Data, leaderboards, and enums.
sidebar_position: 2
---

# API reference

Package export (server or client):

```lua
local KeepData = require(ReplicatedStorage.Packages.dataservicev2)
-- KeepData.Server      (server only)
-- KeepData.Client      (client only)
-- KeepData.Store       (server — CreateStore module table)
-- KeepData.Paths       (typed tree after Init / first store)
-- KeepData.Enum        OrderList.Asc / Desc
-- KeepData.Path        PathOf, tokens, PathValue
-- KeepData.Types       DeepPartial, ClientTree, MapToSignals, ...
-- KeepData.Migration   migration helpers
-- KeepData.Policy      policy types / builders
-- KeepData.Watch       path watchers
-- KeepData.SessionData session store factory
```

---

## KeepData.Server

Server singleton. Writable. Use **`CreateStore`** (preferred) or **`Init`** once.

| Method / property | Returns | Description |
| --- | --- | --- |
| `CreateStore(template, storeName, options?)` | `DataStore<T>` | New store with paths, replication, leaderboards |
| `:Init(options)` | `Server` | Legacy single-store bootstrap |
| `:WaitFor(player)` | `ServerDataHandle<T>` | Default store — yields until loaded |
| `:Get(player)` | `ServerDataHandle<T>?` | Default store if ready |
| `:HasData(player)` | `boolean` | Default store session ready |
| `:GetProfile(player)` | `Profile?` | ProfileStore profile (default store) |
| `:GetBufferStats(player?)` | `table?` | QuickNet buffer metrics |
| `:FlushAll()` | `()` | Flush leaderboard ODS + refresh (all stores) |
| `:Destroy()` | `()` | Tear down stores and replicator |
| `.Paths` | `PathTree<T>` | Default store paths after Init / CreateStore |

### Init / CreateStore options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `Template` | `table` | required | Profile template |
| `StoreName` | `string?` | `"PlayerData"` | ProfileStore name + replication id |
| `UseMock` | `boolean?` | `false` | Mock ProfileStore / mock ODS |
| `KeyPrefix` | `string?` | `"Player_"` | Profile key prefix |
| `Exclude` | `{ PathToken }?` | `nil` | Paths withheld from replication |
| `StrictPaths` | `boolean?` | `true` | Invalid paths error on write |
| `AutoCreateMissingTables` | `boolean?` | `false` | Auto-create nested tables |
| `ReplicateToClient` | `boolean?` | `true` for first store | QuickNet replication |
| `TemplateVersion` | `number?` | `nil` | Migration target version |
| `Migrations` | `{ MigrationStep }?` | `nil` | Ordered `Up` migrations |
| `Policy` | `StorePolicy?` | `nil` | Rate limit / ACL / audit |
| `SessionTemplate` | `table?` | `{}` | Shape for session store |

---

## DataStore\<T\>

Returned by `Server.CreateStore`.

| Method | Returns | Description |
| --- | --- | --- |
| `:WaitFor(player)` | `ServerDataHandle<T>` | Loaded handle |
| `:Get(player)` | `ServerDataHandle<T>?` | Handle if loaded |
| `:HasData(player)` | `boolean` | Session ready |
| `:GetProfile(player)` | `Profile?` | Raw profile |
| `:CreateLeaderboard(config)` | `ServerLeaderboard` | ODS-backed board |
| `:Flush()` | `()`` | Post scores + refresh boards |
| `:Destroy()` | `()` | End sessions, destroy boards |
| `.StoreName` | `string` | Store id / replication id |
| `.Paths` | `PathTree<T>` | Typed tokens for this template |

### CreateLeaderboard config

| Field | Type | Description |
| --- | --- | --- |
| `Name` | `string` | Board id (ODS `{StoreName}/{Name}`) |
| `Key` | `PathToken<number>` | Persisted stat path |
| `UpdateInterval` | `number?` | Seconds between ODS refresh (default 60) |
| `MaxItems` | `number?` | Top N (default 100) |
| `AutoSync` | `boolean?` | Broadcast to clients on refresh (default true) |
| `SyncMode` | `"full"` \| `"delta"`? | Client payload shape |

---

## ServerDataHandle\<T\>

| Member | Description |
| --- | --- |
| `.Value` | Full merged root table |
| `.Data` | Underlying `Data` instance (signals, transient, arrays) |
| `.Session` | Session-only key/value store |
| `:Get(path?)` | Merged read |
| `:GetPersisted(path?)` | ProfileStore read |
| `:Set(path, value)` | Persist + replicate |
| `:Update(path, fn)` | Read-modify-write |
| `:Patch(partial)` | Nested partial write |
| `:Watch(path, fn)` | `(new, old)` on path |

---

## KeepData.Client

Read-only mirror (+ leaderboard views).

| Method | Returns | Description |
| --- | --- | --- |
| `:Init({ StoreNames }?)` | `Data<T>` | Primary store data; registers replication |
| `:WaitForData()` | `Data<T>` | Yields for primary store |
| `:Get()` | `Data<T>?` | Primary store if ready |
| `:GetStore(storeName)` | `ClientStoreView<U>` | Named store view |
| `:GetLeaderboard(name)` | `ClientLeaderboard` | Client board handle |
| `:GetBufferStats()` | `table?` | Replication stats |
| `:Destroy()` | `()` | Cleanup |
| `.Paths` | `PathTree<T>` | Primary store paths |

### ClientStoreView

| Field | Description |
| --- | --- |
| `.StoreName` | Store id |
| `.Data` | `Data` mirror |
| `.Paths` | Path tree for that template |

---

## Data

Per-player instance (server write, client read).

### Read

| Method | Server | Client |
| --- | ---: | ---: |
| `:Get(path?)` | ✓ | ✓ |
| `:GetPersisted(path?)` | ✓ | ✓ |
| `:GetTransient(path?)` | ✓ | ✓ |
| `:HasTransient(path?)` | ✓ | ✓ |
| `:Watch(path, fn)` | ✓ | ✓ |

### Persisted write (server)

`:Set`, `:Update`, `:ArrayInsert`, `:ArrayRemove`

### Transient write (server)

`:SetTransient`, `:UpdateTransient`, `:ClearTransient`, `:ArrayInsertTransient`, `:ArrayRemoveTransient`

### Queries

`:GetOrderedList(path, options)`, `:GetOrderedListWithPriority(path, key, order?)`

### Signals

`:GetChangedSignal(path)`, `:GetIndexChangedSignal(path)`, array insert/remove signals, `.Changed`

---

## Leaderboards

### ServerLeaderboard

| Member | Description |
| --- | --- |
| `.RankChanged` | Signal — `{ UserId, OldRank?, NewRank }` |
| `:Refresh()` | Re-read ODS, sync clients |
| `:_postPlayerScore(userId, value)` | Write score to ODS (call when stat changes) |

### ClientLeaderboard

| Method | Description |
| --- | --- |
| `:Get()` | `{ LeaderboardEntry }` cache |
| `:OnUpdate(fn)` | Full list updates |
| `:OnRankChanged(fn)` | Rank delta notifications |

`LeaderboardEntry`: `{ Rank, UserId, Value }`

---

## Enum

```lua
KeepData.Enum.OrderList.Desc -- default, highest first
KeepData.Enum.OrderList.Asc
```

---

## Quick decision guide

| Goal | API |
| --- | --- |
| New game data module | `Server.CreateStore` + `Client:Init` |
| Grant currency | `handle:Update(Paths.Currencies.Coins, fn)` |
| Global top 100 | `CreateLeaderboard` + `_postPlayerScore` on stat changes |
| Backpack UI | `Client` `GetChangedSignal(Paths.Inventory.Items)` |
| QA god mode | `SetTransient` / `ClearTransient` |
| Hide server flags | `Exclude = { Paths.Admin }` |
| Studio without API | `UseMock = true` |
