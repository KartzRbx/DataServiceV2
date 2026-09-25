--!strict

-- Re-export V3 type surface from submodules.
local Signals = require(script.Signals)
local Leaderboard = require(script.Leaderboard)
local Store = require(script.Store)
local Struct = require(script.Struct)
local ClientTreeMod = require(script.ClientTree)

export type Signal<T> = Signals.Signal<T>
export type MapToSignals<T> = Signals.MapToSignals<T>

export type LeaderboardEntry = Leaderboard.LeaderboardEntry
export type LeaderboardConfig<T> = Leaderboard.LeaderboardConfig<T>
export type ServerLeaderboard<T> = Leaderboard.ServerLeaderboard<T>
export type ClientLeaderboard = Leaderboard.ClientLeaderboard

export type StoreOptions<T> = Store.StoreOptions<T>
export type DataStore<T> = Store.DataStore<T>
export type ServerDataHandle<T> = Store.ServerDataHandle<T>

export type DeepPartial<T> = Struct.DeepPartial<T>
export type ClientTree<T, ExcludeRoot> = ClientTreeMod.ClientTree<T, ExcludeRoot>

return {}
