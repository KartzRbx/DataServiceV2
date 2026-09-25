--!strict

local Players = game:GetService("Players")

local packages = script.Parent.Packages
local Janitor = require(packages.janitor)
local Signal = require(packages.signal)

local Data = require(script.Parent.Data)
local Enums = require(script.Parent.Enums)
local Leaderboard = require(script.Parent.Leaderboard)
local Migration = require(script.Parent.Migration)
local Path = require(script.Parent.Path)
local Policy = require(script.Parent.Policy)
local ProfileStore = require(script.Parent.ProfileStore)
local Replicator = require(script.Parent.Replicator).Server
local SessionData = require(script.Parent.SessionData)
local Watch = require(script.Parent.Watch)

type DataPath = Path.Path
type JanitorT = typeof(Janitor.new())

local DEFAULT_KEY_PREFIX = "Player_"

export type StoreOptions<T> = {
	UseMock: boolean?,
	KeyPrefix: string?,
	Exclude: { DataPath }?,
	StrictPaths: boolean?,
	AutoCreateMissingTables: boolean?,
	ReplicateToClient: boolean?,
	TemplateVersion: number?,
	Migrations: { Migration.MigrationStep }?,
	Policy: Policy.StorePolicy?,
	SessionTemplate: any?,
}

export type LeaderboardConfig<T> = {
	Name: string,
	Key: Path.PathToken<number>,
	UpdateInterval: number?,
	MaxItems: number?,
	AutoSync: boolean?,
	SyncMode: "full" | "delta"?,
}

export type ServerDataHandle<T> = {
	Value: T,
	Data: Data.Data<T>,
	Session: SessionData.SessionStore<any>,
	Set: <V>(self: ServerDataHandle<T>, path: Path.PathToken<V>, value: V) -> (),
	Update: <V>(self: ServerDataHandle<T>, path: Path.PathToken<V>, updater: (current: V) -> V) -> V,
	Get: <V>(self: ServerDataHandle<T>, path: Path.PathToken<V>?) -> V,
	GetPersisted: <V>(self: ServerDataHandle<T>, path: Path.PathToken<V>?) -> V,
	Patch: (self: ServerDataHandle<T>, partial: any) -> (),
	Watch: <V>(self: ServerDataHandle<T>, path: Path.PathToken<V>, callback: (newValue: V, oldValue: V) -> ()) -> Watch.Watcher,
}

export type DataStore<T> = {
	StoreName: string,
	Paths: Path.PathTree<T>,
	WaitFor: (self: DataStore<T>, player: Player) -> ServerDataHandle<T>,
	Get: (self: DataStore<T>, player: Player) -> ServerDataHandle<T>?,
	HasData: (self: DataStore<T>, player: Player) -> boolean,
	GetProfile: (self: DataStore<T>, player: Player) -> any,
	CreateLeaderboard: (self: DataStore<T>, config: LeaderboardConfig<T>) -> Leaderboard.ServerLeaderboard,
	Flush: (self: DataStore<T>) -> (),
	Destroy: (self: DataStore<T>) -> (),
}

type StoreInternal<T> = {
	StoreName: string,
	Paths: Path.PathTree<T>,
	_template: T,
	_options: StoreOptions<T>,
	_janitor: JanitorT?,
	_store: any,
	_data: { [Player]: Data.Data<T> },
	_profiles: { [Player]: any },
	_playerJanitors: { [Player]: JanitorT },
	_waitSignals: { [Player]: typeof(Signal.new()) },
	_ready: { [Player]: boolean },
	_excluded: { [string]: boolean },
	_replicate: boolean,
	_leaderboards: { Leaderboard.ServerLeaderboard },
	_sessions: { [Player]: SessionData.SessionStore<any> },
	_players: { [Player]: Player },
	_destroyed: boolean,
	_onReadyConnection: RBXScriptConnection?,
}

local Store = {}
Store.__index = Store

local function isExcluded(self: StoreInternal<any>, path: DataPath?): boolean
	if not path or #path == 0 then
		return false
	end
	for i = 1, #path do
		local prefix = table.create(i)
		for j = 1, i do
			prefix[j] = path[j]
		end
		if self._excluded[Path.toKey(prefix)] then
			return true
		end
	end
	return false
end

local function buildSnapshot(self: StoreInternal<any>, value: any, prefix: DataPath): any
	if isExcluded(self, prefix) then
		return nil
	end
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		local newPath = table.clone(prefix)
		newPath[#newPath + 1] = k
		if not isExcluded(self, newPath) then
			out[k] = buildSnapshot(self, v, newPath)
		end
	end
	return out
end

local function applyPartial(data: Data.Data<any>, partial: any, prefix: DataPath)
	for key, value in partial do
		local path = table.clone(prefix)
		path[#path + 1] = key
		if type(value) == "table" then
			applyPartial(data, value, path)
		else
			data:Set(path, value)
		end
	end
end

local function wrapHandle<T>(data: Data.Data<T>, session: SessionData.SessionStore<any>): ServerDataHandle<T>
	local handle = {} :: ServerDataHandle<T>
	handle.Data = data
	handle.Session = session
	setmetatable(handle, {
		__index = function(_, key: string)
			if key == "Value" then
				return data:Get()
			end
			return nil
		end,
	})
	function handle:Get<V>(path: Path.PathToken<V>?): V
		return data:Get(path) :: V
	end
	function handle:GetPersisted<V>(path: Path.PathToken<V>?): V
		return data:GetPersisted(path) :: V
	end
	function handle:Set<V>(path: Path.PathToken<V>, value: V)
		data:Set(path, value)
	end
	function handle:Update<V>(path: Path.PathToken<V>, updater: (current: V) -> V): V
		return data:Update(path, updater)
	end
	function handle:Patch(partial: any)
		if type(partial) == "table" then
			applyPartial(data, partial, {})
		end
	end
	function handle:Watch<V>(path: Path.PathToken<V>, callback: (newValue: V, oldValue: V) -> ())
		return Watch.path(data, path, callback)
	end
	return handle
end

function Store.new<T>(template: T, storeName: string, options: StoreOptions<T>?): DataStore<T>
	local self = setmetatable({}, Store) :: any
	self.StoreName = storeName
	self._template = template
	self._options = options or {}
	self._janitor = Janitor.new()
	self._store = nil
	self._data = {}
	self._profiles = {}
	self._playerJanitors = {}
	self._waitSignals = {}
	self._ready = {}
	self._excluded = {}
	self._leaderboards = {}
	self._sessions = {}
	self._players = {}
	self._destroyed = false
	self._replicate = if self._options.ReplicateToClient ~= nil then self._options.ReplicateToClient else true
	self.Paths = Path.createTemplatePaths(template)

	local store = ProfileStore.New(storeName, template :: any)
	self._store = if self._options.UseMock then store.Mock else store

	local excludes = self._options.Exclude
	if excludes then
		for _, p in excludes do
			self._excluded[Path.toKey(p)] = true
		end
	end

	self._onReadyConnection = Replicator.OnReady:Connect(function(player)
		self._ready[player] = true
		if self._replicate and self._data[player] then
			self:_sendInit(player)
		end
	end)
	self._janitor:add(function()
		if self._onReadyConnection then
			self._onReadyConnection:Disconnect()
		end
	end, true)

	self._janitor:add(Players.PlayerAdded:Connect(function(player)
		self:_playerAdded(player)
	end), "Disconnect")
	self._janitor:add(Players.PlayerRemoving:Connect(function(player)
		self:_playerRemoving(player)
	end), "Disconnect")

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_playerAdded(player)
		end)
	end

	return self :: DataStore<T>
end

function Store:_profileKey(player: Player): string
	return (self._options.KeyPrefix or DEFAULT_KEY_PREFIX) .. tostring(player.UserId)
end

function Store:_playerAdded(player: Player)
	if self._destroyed then
		return
	end
	if self._playerJanitors[player] then
		self._playerJanitors[player]:cleanup()
	end
	local playerJanitor = Janitor.new()
	self._playerJanitors[player] = playerJanitor

	local key = self:_profileKey(player)
	local profile = self._store:StartSessionAsync(key, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		player:Kick(`Data load failed ({self.StoreName}) - please rejoin`)
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	if self._options.TemplateVersion then
		profile.Data = Migration.run(profile.Data, {
			TemplateVersion = self._options.TemplateVersion,
			Migrations = self._options.Migrations,
		})
	end

	local sessionEndConnection = profile.OnSessionEnd:Connect(function()
		self._profiles[player] = nil
		if player.Parent then
			player:Kick(`Data session ended ({self.StoreName}) - please rejoin`)
		end
	end)
	playerJanitor:add(function()
		sessionEndConnection:Disconnect()
	end, true)

	if not player:IsDescendantOf(Players) then
		profile:EndSession()
		return
	end

	self._profiles[player] = profile
	self._players[player] = player
	self._sessions[player] = SessionData.new(self._options.SessionTemplate or {})

	local mutationGuard = Policy.buildGuard(self._options.Policy, self.StoreName, function()
		return player
	end)

	local data = Data.new(profile.Data, true, {
		StrictPaths = if self._options.StrictPaths ~= nil then self._options.StrictPaths else true,
		AutoCreateMissingTables = if self._options.AutoCreateMissingTables ~= nil then self._options.AutoCreateMissingTables else false,
		Template = self._template,
		MutationGuard = mutationGuard,
	})
	self._data[player] = data

	if self._replicate then
		local dataChangedConnection = data.Changed:Connect(function(action, path, ...)
			if not self._ready[player] then
				return
			end
			if isExcluded(self, path) then
				return
			end
			Replicator:Send(self.StoreName, player, action, path, ...)
		end)
		playerJanitor:add(function()
			dataChangedConnection:Disconnect()
		end, true)
	end

	local sig = self._waitSignals[player]
	if sig then
		sig:Fire()
		sig:Destroy()
		self._waitSignals[player] = nil
	end

	if self._replicate and self._ready[player] then
		self:_sendInit(player)
	end
end

function Store:_sendInit(player: Player)
	local data = self._data[player]
	if not data then
		return
	end
	local snapshot = buildSnapshot(self, data:Get(), {})
	Replicator:Send(self.StoreName, player, Enums.Init, nil, snapshot)
end

function Store:_postLeaderboardsForPlayer(player: Player)
	local data = self._data[player]
	if not data then
		return
	end
	for _, board in self._leaderboards do
		local keyPath = (board :: any)._keyPath
		if keyPath then
			local value = data:GetPersisted(keyPath)
			if type(value) == "number" then
				board:_postPlayerScore(player.UserId, value)
			end
		end
	end
end

function Store:_playerRemoving(player: Player)
	self:_postLeaderboardsForPlayer(player)

	local playerJanitor = self._playerJanitors[player]
	if playerJanitor then
		playerJanitor:cleanup()
		self._playerJanitors[player] = nil
	end

	local data = self._data[player]
	if data then
		data:Destroy()
		self._data[player] = nil
	end
	self._sessions[player] = nil
	self._players[player] = nil

	local profile = self._profiles[player]
	if profile then
		profile:EndSession()
		self._profiles[player] = nil
	end

	self._ready[player] = nil

	local sig = self._waitSignals[player]
	if sig then
		sig:Destroy()
		self._waitSignals[player] = nil
	end
end

function Store:WaitFor<T>(player: Player): ServerDataHandle<T>
	local data = self._data[player]
	if data then
		return wrapHandle(data, self._sessions[player] or SessionData.new({}))
	end
	if not player:IsDescendantOf(Players) then
		error(`DataService Store ({self.StoreName}): WaitFor called for a player that is not in Players`)
	end
	local sig = self._waitSignals[player]
	if not sig then
		sig = Signal.new()
		self._waitSignals[player] = sig
	end
	sig:Wait()
	local loaded = self._data[player]
	assert(loaded ~= nil, `DataService Store ({self.StoreName}): player data was not available after wait`)
	return wrapHandle(loaded, self._sessions[player] or SessionData.new({}))
end

function Store:Get(player: Player): ServerDataHandle<any>?
	local data = self._data[player]
	if data then
		return wrapHandle(data, self._sessions[player] or SessionData.new({}))
	end
	return nil
end

function Store:HasData(player: Player): boolean
	return self._data[player] ~= nil
end

function Store:GetProfile(player: Player): any
	return self._profiles[player]
end

function Store:CreateLeaderboard<T>(config: LeaderboardConfig<T>): Leaderboard.ServerLeaderboard
	assert(type(config.Name) == "string" and config.Name ~= "", "CreateLeaderboard requires config.Name")
	assert(config.Key ~= nil, "CreateLeaderboard requires config.Key as PathToken<number>")

	local keyPath = Leaderboard.resolveKeyPath(config.Key)
	local orderedName = `{self.StoreName}/{config.Name}`

	local board = Leaderboard.createServer(orderedName, {
		Name = config.Name,
		Key = keyPath,
		UpdateInterval = config.UpdateInterval,
		MaxItems = config.MaxItems,
		AutoSync = config.AutoSync,
		SyncMode = config.SyncMode,
		UseMock = self._options.UseMock,
	}, function(payload)
		Leaderboard.broadcast(payload)
	end)

	table.insert(self._leaderboards, board)
	board:Refresh()
	return board
end

function Store:Flush()
	for player in self._data do
		self:_postLeaderboardsForPlayer(player)
	end
	for _, board in self._leaderboards do
		board:Refresh()
	end
end

function Store:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for player in self._data do
		self:_playerRemoving(player)
	end
	for _, board in self._leaderboards do
		board:Destroy()
	end
	table.clear(self._leaderboards)
	if self._janitor then
		self._janitor:cleanup()
		self._janitor = nil
	end
end

return Store
