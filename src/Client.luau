const RunService = game:GetService("RunService")

assert(RunService:IsClient(), "DataService.Client may only be required on the client")

local packages = script.Parent.Packages

const Janitor = require(packages.janitor)
const Signal = require(packages.signal)

const Data = require(script.Parent.Data)
const Path = require(script.Parent.Path)
const Replicator = require(script.Parent.Replicator).Client
const Leaderboard = require(script.Parent.Leaderboard)
const ClientRegistry = require(script.Parent.ClientRegistry)

type JanitorT = typeof(Janitor.new())

export type ClientInitOptions = {
	StoreNames: { string }?,
}

export type ClientApi<T> = {
	Init: (self: ClientApi<T>, options: ClientInitOptions?) -> Data.Data<T>,
	WaitForData: (self: ClientApi<T>) -> Data.Data<T>,
	Get: (self: ClientApi<T>) -> Data.Data<T>?,
	GetStore: <U>(self: ClientApi<T>, storeName: string) -> ClientRegistry.ClientStoreView<U>,
	GetLeaderboard: (self: ClientApi<T>, name: string) -> Leaderboard.ClientLeaderboard,
	GetBufferStats: (self: ClientApi<T>) -> ClientBufferStats?,
	Destroy: (self: ClientApi<T>) -> (),
	Paths: Path.PathTree<T>,
}

type ClientBufferStats = {
	Bytes: number,
	Messages: number,
	LastPacketBytes: number,
	LastUtilization: number,
}

const Client = {
	_initialized = false,
	_primaryStoreName = "PlayerData",
	_janitor = nil :: JanitorT?,
	_bufferStats = nil :: ClientBufferStats?,
	_loaded = Signal.new(),
}

function Client:Init(options: ClientInitOptions?)
	if not self._initialized then
		self._initialized = true
		self._janitor = Janitor.new()
		self._janitor:add(self._loaded, "Destroy")

		local storeNames = if options and options.StoreNames then options.StoreNames else { self._primaryStoreName }
		if #storeNames > 0 then
			self._primaryStoreName = storeNames[1]
		end
		for _, storeName in storeNames do
			ClientRegistry.registerStore(storeName)
		end

		local bufferChangedConnection = Replicator.BufferChanged:Connect(function(stats)
			self._bufferStats = stats
		end)
		self._janitor:add(function()
			bufferChangedConnection:Disconnect()
		end, true)
	end

	return self:WaitForData()
end

function Client:WaitForData<T>(): Data.Data<T>
	local view = ClientRegistry.waitForStore<T>(self._primaryStoreName)
	self.Paths = view.Paths
	self._loaded:Fire()
	return view.Data
end

function Client:Get()
	local view = ClientRegistry.getDefaultStore()
	if view then
		self.Paths = view.Paths
		return view.Data
	end
	return nil
end

function Client:GetStore<U>(storeName: string): ClientRegistry.ClientStoreView<U>
	return ClientRegistry.waitForStore<U>(storeName)
end

function Client:GetBufferStats()
	return self._bufferStats or Replicator:GetBufferStats()
end

function Client:Destroy()
	if self._janitor then
		self._janitor:cleanup()
		self._janitor = nil
	end
	Replicator:Destroy()
end

const PublicClient: ClientApi<never> = {
	Init = function<T>(self: ClientApi<T>, options: ClientInitOptions?): Data.Data<T>
		return Client:Init(options) :: Data.Data<T>
	end,
	WaitForData = function<T>(self: ClientApi<T>): Data.Data<T>
		return Client:WaitForData() :: Data.Data<T>
	end,
	Get = function<T>(self: ClientApi<T>): Data.Data<T>?
		return Client:Get()
	end,
	GetStore = function<T, U>(_: ClientApi<T>, storeName: string): ClientRegistry.ClientStoreView<U>
		return Client:GetStore(storeName)
	end,
	GetLeaderboard = function(_, name: string): Leaderboard.ClientLeaderboard
		return Leaderboard.getClient(name)
	end,
	GetBufferStats = function(_): ClientBufferStats?
		return Client:GetBufferStats()
	end,
	Destroy = function(_)
		Client:Destroy()
	end,
	Paths = Path.rootToken(),
}

setmetatable(PublicClient, {
	__index = function(_, key)
		if key == "Paths" then
			local view = ClientRegistry.getDefaultStore()
			if view and view.Paths then
				return view.Paths
			end
			return Client.Paths or Path.rootToken()
		end
		return nil
	end,
})

return PublicClient
