<p align="center">
  <img src="www/public/keepdata-mark.png" alt="KeepData" width="200" />
</p>

# KeepData

Typed **stores**, **paths**, **leaderboards**, and **ProfileStore** sync for Roblox Luau.

**Docs:** https://kartzrbx.github.io/KeepData/  
**API:** https://kartzrbx.github.io/KeepData/docs/api-reference  
**Repo:** https://github.com/KartzRbx/KeepData  

Legacy Wally name: `kartzrbx/keepdata` (frozen at 3.2.0). New installs use **`kartzrbx/keepdata`**.

See [BRAND.md](BRAND.md) for logo assets.

## Install

```toml
[dependencies]
keepdata = "kartzrbx/keepdata@1.0.0"
```

```bash
wally install
```

Rojo: sync `Packages` to `ReplicatedStorage.Packages`.

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

## Highlights

- `CreateStore`, `ServerDataHandle` (`Patch`, `Watch`), multi-store `GetStore`
- Leaderboards on path tokens + client `GetLeaderboard`
- Migrations, policy, session data, transient overlay, ordered lists
- Guides: [inventory](https://kartzrbx.github.io/KeepData/docs/guides/inventory-system), [leaderboard](https://kartzrbx.github.io/KeepData/docs/guides/leaderboard-system)

## Local docs

```powershell
npm install
npm run docs
```

Sources in `docs/`; CI publishes to GitHub Pages on push to `master`.
