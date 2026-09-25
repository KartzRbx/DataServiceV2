<p align="center">
  <img src="www/public/keepdata-mark.png" alt="KeepData" width="200" />
</p>

# KeepData

Typed **stores**, **paths**, **leaderboards**, and **ProfileStore** sync for Roblox Luau.

**Docs:** https://kartzrbx.github.io/DataServiceV2/  
**API:** https://kartzrbx.github.io/DataServiceV2/docs/api-reference  
**Repo:** https://github.com/KartzRbx/DataServiceV2  

Wally: **`kartzrbx/keepdata@1.0.0`**

See [BRAND.md](BRAND.md) for logo assets.

## Install

```toml
[dependencies]
keepdata = "kartzrbx/keepdata@1.0.0"
```

```bash
wally install
```

## Quick start

**Server**

```lua
local KeepData = require(ReplicatedStorage.Packages.keepdata)
local PlayerStore = KeepData.Server.CreateStore(DataTemplate, "PlayerData", { StrictPaths = true })
local handle = PlayerStore:WaitFor(player)
handle:Set(PlayerStore.Paths.Currencies.Coins, 100)
```

**Client**

```lua
local KeepData = require(ReplicatedStorage.Packages.keepdata)
local data = KeepData.Client:Init({ StoreNames = { "PlayerData" } })
print(data:Get(KeepData.Client.Paths.Currencies.Coins))
```

## Guides

- [Inventory](https://kartzrbx.github.io/DataServiceV2/docs/guides/inventory-system)
- [Leaderboard](https://kartzrbx.github.io/DataServiceV2/docs/guides/leaderboard-system)

## Local docs

```powershell
npm install
npm run docs
```
