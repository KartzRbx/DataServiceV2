--!strict

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local packages = script.Parent.Packages
local Signal = require(packages.signal)
local QuickNet = require(packages.quicknet)

local Path = require(script.Parent.Path)

local LEADERBOARD_EVENT = "DataServiceV2/Leaderboard"
local quickNetData = QuickNet.Data
local leaderboardEvent = QuickNet:register(LEADERBOARD_EVENT, quickNetData.Any)

export type LeaderboardEntry = {
	Rank: number,
	UserId: number,
	Value: number,
}

export type RankChange = {
	UserId: number,
	OldRank: number?,
	NewRank: number,
}

export type LeaderboardConfig = {
	Name: string,
	Key: Path.Path,
	UpdateInterval: number?,
	MaxItems: number?,
	AutoSync: boolean?,
	SyncMode: "full" | "delta"?,
	UseMock: boolean?,
}

export type ServerLeaderboard = {
	Name: string,
	UpdateInterval: number,
	MaxItems: number,
	AutoSync: boolean,
	SyncMode: "full" | "delta",
	RankChanged: typeof(Signal.new()),
	Refresh: (self: ServerLeaderboard) -> (),
	Destroy: (self: ServerLeaderboard) -> (),
	_postPlayerScore: (self: ServerLeaderboard, userId: number, value: number) -> (),
}

export type ClientLeaderboard = {
	Name: string,
	Get: (self: ClientLeaderboard) -> { LeaderboardEntry },
	OnUpdate: (self: ClientLeaderboard, callback: (top: { LeaderboardEntry }) -> ()) -> RBXScriptConnection,
	OnRankChanged: (self: ClientLeaderboard, callback: (change: RankChange) -> ()) -> RBXScriptConnection,
}

local function cloneEntries(entries: { LeaderboardEntry }): { LeaderboardEntry }
	local out = table.create(#entries)
	for i, entry in entries do
		out[i] = {
			Rank = entry.Rank,
			UserId = entry.UserId,
			Value = entry.Value,
		}
	end
	return out
end

local function rankMap(entries: { LeaderboardEntry }): { [number]: number }
	local map = {}
	for _, entry in entries do
		map[entry.UserId] = entry.Rank
	end
	return map
end

local ServerLeaderboardImpl = {}
ServerLeaderboardImpl.__index = ServerLeaderboardImpl

function ServerLeaderboardImpl.new(
	orderedStoreName: string,
	config: LeaderboardConfig,
	onBroadcast: (payload: any) -> ()
): ServerLeaderboard
	local self = setmetatable({}, ServerLeaderboardImpl)
	self.Name = config.Name
	self.UpdateInterval = config.UpdateInterval or 60
	self.MaxItems = config.MaxItems or 100
	self.AutoSync = if config.AutoSync ~= nil then config.AutoSync else true
	self.SyncMode = config.SyncMode or "delta"
	self._keyPath = Path.clone(config.Key)
	self._ods = if config.UseMock
		then DataStoreService:GetOrderedDataStore(`Mock_{orderedStoreName}`)
		else DataStoreService:GetOrderedDataStore(orderedStoreName)
	self._cache = {} :: { LeaderboardEntry }
	self._destroyed = false
	self._onBroadcast = onBroadcast
	self.RankChanged = Signal.new()
	self._thread = task.spawn(function()
		while not self._destroyed do
			self:Refresh()
			task.wait(self.UpdateInterval)
		end
	end)
	return self :: any
end

function ServerLeaderboardImpl:Refresh()
	if self._destroyed then
		return
	end
	local ok, pages = pcall(function()
		return self._ods:GetSortedAsync(false, self.MaxItems)
	end)
	if not ok or not pages then
		return
	end

	local entries = {} :: { LeaderboardEntry }
	local rank = 1
	while true do
		local page = pages:GetCurrentPage()
		for _, item in page do
			local userId = tonumber(item.key)
			local value = tonumber(item.value)
			if userId and value then
				entries[#entries + 1] = {
					Rank = rank,
					UserId = userId,
					Value = value,
				}
				rank += 1
			end
		end
		if pages.IsFinished then
			break
		end
		local advanced = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not advanced then
			break
		end
	end

	local oldMap = rankMap(self._cache)
	local newMap = rankMap(entries)
	for userId, newRank in newMap do
		local oldRank = oldMap[userId]
		if oldRank ~= newRank then
			self.RankChanged:Fire({
				UserId = userId,
				OldRank = oldRank,
				NewRank = newRank,
			})
		end
	end

	self._cache = entries
	if self.AutoSync then
		if self.SyncMode == "full" then
			self._onBroadcast({
				Name = self.Name,
				Mode = "full",
				Entries = cloneEntries(entries),
			})
		else
			local changes = {} :: { RankChange }
			for userId, newRank in newMap do
				local oldRank = oldMap[userId]
				if oldRank ~= newRank then
					changes[#changes + 1] = {
						UserId = userId,
						OldRank = oldRank,
						NewRank = newRank,
					}
				end
			end
			self._onBroadcast({
				Name = self.Name,
				Mode = "delta",
				Entries = cloneEntries(entries),
				RankChanges = changes,
			})
		end
	end
end

function ServerLeaderboardImpl:_postPlayerScore(userId: number, value: number)
	if self._destroyed then
		return
	end
	if type(value) ~= "number" then
		return
	end
	pcall(function()
		self._ods:SetAsync(tostring(userId), math.floor(value))
	end)
end

function ServerLeaderboardImpl:Destroy()
	self._destroyed = true
	self.RankChanged:Destroy()
end

local clientCaches: { [string]: { LeaderboardEntry } } = {}
local clientSignals: { [string]: typeof(Signal.new()) } = {}
local clientRankSignals: { [string]: typeof(Signal.new()) } = {}
local clientHandles: { [string]: ClientLeaderboard } = {}
local clientInitialized = false

local function ensureClientListener()
	if clientInitialized or RunService:IsServer() then
		return
	end
	clientInitialized = true
	leaderboardEvent.OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		local name = payload.Name
		if type(name) ~= "string" then
			return
		end
		if type(payload.Entries) == "table" then
			clientCaches[name] = cloneEntries(payload.Entries)
		end
		local sig = clientSignals[name]
		if sig and clientCaches[name] then
			sig:Fire(clientCaches[name])
		end
		if type(payload.RankChanges) == "table" then
			local rankSig = clientRankSignals[name]
			if rankSig then
				for _, change in payload.RankChanges do
					rankSig:Fire(change)
				end
			end
		end
	end)
end

local ClientLeaderboardImpl = {}
ClientLeaderboardImpl.__index = ClientLeaderboardImpl

function ClientLeaderboardImpl.new(name: string): ClientLeaderboard
	ensureClientListener()
	local self = setmetatable({}, ClientLeaderboardImpl)
	self.Name = name
	if not clientSignals[name] then
		clientSignals[name] = Signal.new()
	end
	if not clientRankSignals[name] then
		clientRankSignals[name] = Signal.new()
	end
	if not clientCaches[name] then
		clientCaches[name] = {}
	end
	return self :: any
end

function ClientLeaderboardImpl:Get(): { LeaderboardEntry }
	return cloneEntries(clientCaches[self.Name] or {})
end

function ClientLeaderboardImpl:OnUpdate(callback: (top: { LeaderboardEntry }) -> ()): RBXScriptConnection
	ensureClientListener()
	local sig = clientSignals[self.Name]
	if not sig then
		sig = Signal.new()
		clientSignals[self.Name] = sig
	end
	return sig:Connect(callback)
end

function ClientLeaderboardImpl:OnRankChanged(callback: (change: RankChange) -> ()): RBXScriptConnection
	ensureClientListener()
	local sig = clientRankSignals[self.Name]
	if not sig then
		sig = Signal.new()
		clientRankSignals[self.Name] = sig
	end
	return sig:Connect(callback)
end

local Leaderboard = {}

function Leaderboard.createServer(
	orderedStoreName: string,
	config: LeaderboardConfig,
	onBroadcast: (payload: any) -> ()
): ServerLeaderboard
	return ServerLeaderboardImpl.new(orderedStoreName, config, onBroadcast)
end

function Leaderboard.broadcast(payload: any)
	if not RunService:IsServer() then
		return
	end
	leaderboardEvent:FireAllClients(payload)
end

function Leaderboard.getClient(name: string): ClientLeaderboard
	if RunService:IsServer() then
		error("Leaderboard.getClient is client-only", 2)
	end
	local cached = clientHandles[name]
	if cached then
		return cached
	end
	local handle = ClientLeaderboardImpl.new(name)
	clientHandles[name] = handle
	return handle
end

function Leaderboard.resolveKeyPath(key: any): Path.Path
	if Path.isToken(key) then
		local segments = Path.toArray(key)
		if segments then
			return segments
		end
	end
	if type(key) == "table" then
		return Path.clone(key :: Path.Path)
	end
	error("Leaderboard config.Key must be a PathToken or path array", 2)
end

return Leaderboard
