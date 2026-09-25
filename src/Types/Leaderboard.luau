--!strict

local Path = require(script.Parent.Parent.Path)

export type LeaderboardEntry = {
	Rank: number,
	UserId: number,
	Value: number,
}

export type LeaderboardConfig<T> = {
	Name: string,
	Key: Path.PathToken<number>,
	UpdateInterval: number?,
	MaxItems: number?,
	AutoSync: boolean?,
}

export type ServerLeaderboard<T> = {
	Name: string,
	UpdateInterval: number,
	MaxItems: number,
	AutoSync: boolean,
	Refresh: (self: ServerLeaderboard<T>) -> (),
	Destroy: (self: ServerLeaderboard<T>) -> (),
}

export type ClientLeaderboard = {
	Name: string,
	Get: (self: ClientLeaderboard) -> { LeaderboardEntry },
	OnUpdate: (self: ClientLeaderboard, callback: (top: { LeaderboardEntry }) -> ()) -> RBXScriptConnection,
}

return {}
