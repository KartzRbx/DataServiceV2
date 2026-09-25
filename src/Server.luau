const RunService = game:GetService("RunService")

assert(RunService:IsServer(), "DataService.Server may only be required on the server")

local Path = require(script.Parent.Path)
local Replicator = require(script.Parent.Replicator).Server
local StoreModule = require(script.Parent.Store)

export type Options<T> = StoreModule.StoreOptions<T> & {
	Template: T,
	StoreName: string?,
}

export type ServerApi<T> = {
	Init: (self: ServerApi<T>, options: Options<T>) -> ServerApi<T>,
	CreateStore: <U>(self: ServerApi<T>, template: U, storeName: string, options: StoreModule.StoreOptions<U>?) -> StoreModule.DataStore<U>,
	WaitFor: (self: ServerApi<T>, player: Player) -> StoreModule.ServerDataHandle<T>,
	Get: (self: ServerApi<T>, player: Player) -> StoreModule.ServerDataHandle<T>?,
	HasData: (self: ServerApi<T>, player: Player) -> boolean,
	GetProfile: (self: ServerApi<T>, player: Player) -> any,
	GetBufferStats: (self: ServerApi<T>, player: Player?) -> any,
	Destroy: (self: ServerApi<T>) -> (),
	Paths: Path.PathTree<T>,
}

export type ServerApiFor<T> = ServerApi<T>

local _defaultStore: StoreModule.DataStore<any>? = nil
local _replicatingStores: { [string]: StoreModule.DataStore<any> } = {}
local _extraStores: { StoreModule.DataStore<any> } = {}

local function assertDefaultStore()
	if not _defaultStore then
		error("DataService.Server: call Init() or use CreateStore() first", 2)
	end
	return _defaultStore
end

local function registerStore(store: StoreModule.DataStore<any>)
	if (store :: any)._replicate then
		assert(_replicatingStores[store.StoreName] == nil, `DataService: store "{store.StoreName}" already replicates to client`)
		_replicatingStores[store.StoreName] = store
	end
end

local function buildStoreOptions<T>(options: StoreModule.StoreOptions<T>?, replicateDefault: boolean?): StoreModule.StoreOptions<T>
	return {
		UseMock = options and options.UseMock,
		KeyPrefix = options and options.KeyPrefix,
		Exclude = options and options.Exclude,
		StrictPaths = options and options.StrictPaths,
		AutoCreateMissingTables = options and options.AutoCreateMissingTables,
		ReplicateToClient = if options and options.ReplicateToClient ~= nil
			then options.ReplicateToClient
			else replicateDefault,
		TemplateVersion = options and options.TemplateVersion,
		Migrations = options and options.Migrations,
		Policy = options and options.Policy,
		SessionTemplate = options and options.SessionTemplate,
	}
end

local Server = {}

function Server.CreateStore<U>(template: U, storeName: string, options: StoreModule.StoreOptions<U>?): StoreModule.DataStore<U>
	local replicateDefault = next(_replicatingStores) == nil
	local store = StoreModule.new(template, storeName, buildStoreOptions(options, replicateDefault))
	registerStore(store)
	if not _defaultStore then
		_defaultStore = store
	end
	table.insert(_extraStores, store)
	return store
end

function Server:Init<T>(options: Options<T>)
	assert(not _defaultStore, "DataService.Server already initialized")
	assert(options and options.Template, "DataService.Server:Init requires options.Template")

	local storeName = options.StoreName or "PlayerData"
	local store = StoreModule.new(options.Template, storeName, buildStoreOptions(options, true))
	registerStore(store)
	_defaultStore = store
	table.insert(_extraStores, store)
end

function Server:WaitFor<T>(player: Player): StoreModule.ServerDataHandle<T>
	return assertDefaultStore():WaitFor(player)
end

function Server:Get(player: Player)
	return assertDefaultStore():Get(player)
end

function Server:HasData(player: Player): boolean
	return assertDefaultStore():HasData(player)
end

function Server:GetProfile(player: Player): any
	return assertDefaultStore():GetProfile(player)
end

function Server:FlushAll()
	for _, store in _extraStores do
		store:Flush()
	end
end

function Server:Destroy()
	for _, store in _extraStores do
		store:Destroy()
	end
	table.clear(_extraStores)
	table.clear(_replicatingStores)
	_defaultStore = nil
	Replicator:Destroy()
end

local PublicServer: ServerApi<never> = {
	Init = function<T>(self: ServerApi<T>, options: Options<T>): ServerApi<T>
		Server:Init(options)
		self.Paths = _defaultStore and _defaultStore.Paths or Path.rootToken()
		return self :: ServerApi<T>
	end,
	CreateStore = function<T, U>(_: ServerApi<T>, template: U, storeName: string, options: StoreModule.StoreOptions<U>?)
		return Server.CreateStore(template, storeName, options)
	end,
	WaitFor = function<T>(_, player: Player): StoreModule.ServerDataHandle<T>
		return Server:WaitFor(player)
	end,
	Get = function<T>(_, player: Player): StoreModule.ServerDataHandle<T>?
		return Server:Get(player)
	end,
	HasData = function(_, player: Player): boolean
		return Server:HasData(player)
	end,
	GetProfile = function(_, player: Player)
		return Server:GetProfile(player)
	end,
	GetBufferStats = function(_, player: Player?)
		return Replicator:GetBufferStats(player)
	end,
	Destroy = function(_)
		Server:Destroy()
	end,
	Paths = Path.rootToken(),
}

setmetatable(PublicServer, {
	__index = function(_, key)
		if key == "Paths" then
			if _defaultStore then
				return _defaultStore.Paths
			end
			return Path.rootToken()
		end
		return nil
	end,
})

game:BindToClose(function()
	Server:FlushAll()
end)

return PublicServer
