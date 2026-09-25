--!strict

-- Ephemeral per-player session state (not saved to ProfileStore).

local SessionData = {}

export type SessionStore<T> = {
	Get: (self: SessionStore<T>) -> T,
	Set: (self: SessionStore<T>, value: T) -> (),
	Update: (self: SessionStore<T>, fn: (T) -> T) -> T,
	Clear: (self: SessionStore<T>) -> (),
}

type Internal<T> = {
	_value: T,
}

local SessionStoreImpl = {}
SessionStoreImpl.__index = SessionStoreImpl

function SessionData.new<T>(initial: T): SessionStore<T>
	local self = setmetatable({
		_value = initial,
	}, SessionStoreImpl)
	return self :: any
end

function SessionStoreImpl:Get(): any
	return self._value
end

function SessionStoreImpl:Set(value: any)
	self._value = value
end

function SessionStoreImpl:Update(fn: (any) -> any): any
	self._value = fn(self._value)
	return self._value
end

function SessionStoreImpl:Clear()
	self._value = nil
end

return SessionData
