<p align="center">
  <img src="www/public/keepdata-mark.png" alt="KeepData" width="200" />
</p>

# KeepData

Typed **stores**, **paths**, **leaderboards**, and **ProfileStore** sync for Roblox Luau. Shipped on Wally as **`kartzrbx/dataservicev2`** (package folder `dataservicev2`).

**Docs:** https://kartzrbx.github.io/DataServiceV2/  
**API:** https://kartzrbx.github.io/DataServiceV2/docs/api-reference  
**Repo:** https://github.com/KartzRbx/DataServiceV2  

See [BRAND.md](BRAND.md) for the logo.

## Install

```toml
[dependencies]
dataservicev2 = "kartzrbx/dataservicev2@3.2.0"
```

```bash
wally install
```

## Quick start

**Server**

```lua
local KeepData = require(ReplicatedStorage.Packages.dataservicev2)
local PlayerStore = KeepData.Server.CreateStore(DataTemplate, "PlayerData", { StrictPaths = true })
local handle = PlayerStore:WaitFor(player)
handle:Set(PlayerStore.Paths.Currencies.Coins, 100)
```

**Client**

```lua
local KeepData = require(ReplicatedStorage.Packages.dataservicev2)
local data = KeepData.Client:Init({ StoreNames = { "PlayerData" } })
print(data:Get(KeepData.Client.Paths.Currencies.Coins))
```

## Highlights (v3.2)

- `CreateStore`, `ServerDataHandle` (`Patch`, `Watch`), multi-store `GetStore`
- Leaderboards on path tokens + client `GetLeaderboard`
- Migrations, policy, session data, transient overlay, ordered lists
- Guides: [inventory](https://kartzrbx.github.io/DataServiceV2/docs/guides/inventory-system), [leaderboard](https://kartzrbx.github.io/DataServiceV2/docs/guides/leaderboard-system)

## Local docs

```powershell
npm install
npm run docs
```

Sources in `docs/`; CI publishes `www/dist` to GitHub Pages on push to `master`.

## Local Rojo test

```powershell
.\scripts\setup-test-env.ps1
cd Test
rojo serve
```
