--!strict

local Path = require(script.Parent.Parent.Path)
local Data = require(script.Parent.Parent.Data)
local LeaderboardTypes = require(script.Parent.Leaderboard)

export type StoreOptions<T> = {
	UseMock: boolean?,
	KeyPrefix: string?,
	Exclude: { Path.Path }?,
	StrictPaths: boolean?,
	AutoCreateMissingTables: boolean?,
}

export type DataStore<T> = {
	StoreName: string,
	Paths: Path.PathTree<T>,
	WaitFor: (self: DataStore<T>, player: Player) -> ServerDataHandle<T>,
	Get: (self: DataStore<T>, player: Player) -> ServerDataHandle<T>?,
	HasData: (self: DataStore<T>, player: Player) -> boolean,
	GetProfile: (self: DataStore<T>, player: Player) -> any,
	CreateLeaderboard: (self: DataStore<T>, config: LeaderboardTypes.LeaderboardConfig<T>) -> LeaderboardTypes.ServerLeaderboard<T>,
	Destroy: (self: DataStore<T>) -> (),
}

export type ServerDataHandle<T> = {
	Value: T,
	Data: Data.Data<T>,
	Set: <V>(self: ServerDataHandle<T>, path: Path.PathToken<V>, value: V) -> (),
	Update: <V>(self: ServerDataHandle<T>, path: Path.PathToken<V>, updater: (current: V) -> V) -> V,
	Get: <V>(self: ServerDataHandle<T>, path: Path.PathToken<V>?) -> V,
	GetPersisted: <V>(self: ServerDataHandle<T>, path: Path.PathToken<V>?) -> V,
}

return {}
