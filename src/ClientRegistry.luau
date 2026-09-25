--!strict

local packages = script.Parent.Packages
local Signal = require(packages.signal)

local Data = require(script.Parent.Data)
local Enums = require(script.Parent.Enums)
local Path = require(script.Parent.Path)
local Replicator = require(script.Parent.Replicator).Client

export type ClientStoreView<T> = {
	StoreName: string,
	Data: Data.Data<T>,
	Paths: Path.PathTree<T>,
	Wait: (self: ClientStoreView<T>) -> Data.Data<T>,
}

type StoreBucket = {
	data: Data.Data<any>?,
	paths: Path.PathTree<any>?,
	loaded: typeof(Signal.new()),
}

local ClientRegistry = {
	_initialized = false,
	_stores = {} :: { [string]: StoreBucket },
	_defaultStoreName = nil :: string?,
}

local function getBucket(storeId: string): StoreBucket
	local bucket = ClientRegistry._stores[storeId]
	if not bucket then
		bucket = {
			data = nil,
			paths = nil,
			loaded = Signal.new(),
		}
		ClientRegistry._stores[storeId] = bucket
	end
	return bucket
end

local function bindStoreHandlers(storeId: string)
	Replicator:OnStore(storeId, Enums.Init, function(_storeId, _path, snapshot)
		local bucket = getBucket(storeId)
		if bucket.data then
			bucket.data:Destroy()
		end
		bucket.data = Data.new(snapshot, false, {
			Template = snapshot,
		})
		bucket.paths = Path.createTemplatePaths(snapshot)
		if not ClientRegistry._defaultStoreName then
			ClientRegistry._defaultStoreName = storeId
		end
		bucket.loaded:Fire()
	end)

	Replicator:OnStore(storeId, Enums.Set, function(_sid, path, value)
		local bucket = ClientRegistry._stores[storeId]
		if bucket and bucket.data then
			Data._applySet(bucket.data, path, value)
		end
	end)
	Replicator:OnStore(storeId, Enums.ArrayInsert, function(_sid, path, value, index)
		local bucket = ClientRegistry._stores[storeId]
		if bucket and bucket.data then
			Data._applyArrayInsert(bucket.data, path, value, index)
		end
	end)
	Replicator:OnStore(storeId, Enums.ArrayRemove, function(_sid, path, index)
		local bucket = ClientRegistry._stores[storeId]
		if bucket and bucket.data then
			Data._applyArrayRemove(bucket.data, path, index)
		end
	end)
	Replicator:OnStore(storeId, Enums.SetTransient, function(_sid, path, value)
		local bucket = ClientRegistry._stores[storeId]
		if bucket and bucket.data then
			Data._applyTransientSet(bucket.data, path, value)
		end
	end)
	Replicator:OnStore(storeId, Enums.ArrayInsertTransient, function(_sid, path, value, index)
		local bucket = ClientRegistry._stores[storeId]
		if bucket and bucket.data then
			Data._applyTransientArrayInsert(bucket.data, path, value, index)
		end
	end)
	Replicator:OnStore(storeId, Enums.ArrayRemoveTransient, function(_sid, path, index)
		local bucket = ClientRegistry._stores[storeId]
		if bucket and bucket.data then
			Data._applyTransientArrayRemove(bucket.data, path, index)
		end
	end)
	Replicator:OnStore(storeId, Enums.ClearTransient, function(_sid, path)
		local bucket = ClientRegistry._stores[storeId]
		if bucket and bucket.data then
			Data._applyTransientClear(bucket.data, path)
		end
	end)
end

function ClientRegistry.ensureNetworking()
	if ClientRegistry._initialized then
		return
	end
	ClientRegistry._initialized = true
	Replicator:NotifyReady()
end

function ClientRegistry.registerStore(storeId: string)
	ClientRegistry.ensureNetworking()
	if ClientRegistry._stores[storeId] then
		return
	end
	getBucket(storeId)
	bindStoreHandlers(storeId)
end

function ClientRegistry.waitForStore<T>(storeId: string): ClientStoreView<T>
	ClientRegistry.registerStore(storeId)
	local bucket = getBucket(storeId)
	if bucket.data then
		return {
			StoreName = storeId,
			Data = bucket.data :: Data.Data<T>,
			Paths = bucket.paths :: Path.PathTree<T>,
			Wait = function(self)
				return self.Data
			end,
		}
	end
	bucket.loaded:Wait()
	return {
		StoreName = storeId,
		Data = bucket.data :: Data.Data<T>,
		Paths = bucket.paths :: Path.PathTree<T>,
		Wait = function(self)
			return self.Data
		end,
	}
end

function ClientRegistry.getDefaultStore<T>(): ClientStoreView<T>?
	local name = ClientRegistry._defaultStoreName
	if not name then
		return nil
	end
	local bucket = ClientRegistry._stores[name]
	if not bucket or not bucket.data then
		return nil
	end
	return {
		StoreName = name,
		Data = bucket.data :: Data.Data<T>,
		Paths = bucket.paths :: Path.PathTree<T>,
		Wait = function(self)
			return self.Data
		end,
	}
end

function ClientRegistry.getPaths(storeId: string): Path.PathTree<any>?
	local bucket = ClientRegistry._stores[storeId]
	return if bucket then bucket.paths else nil
end

return ClientRegistry
