--!strict

local Path = require(script.Parent.Path)

export type AuditEntry = {
	StoreName: string,
	Player: Player,
	Action: string,
	Path: Path.Path,
	OldValue: any?,
	NewValue: any?,
	Timestamp: number,
}

export type StorePolicy = {
	MutationsPerSecond: number?,
	CanMutate: ((player: Player, action: string, path: Path.Path, newValue: any?) -> boolean)?,
	Audit: ((entry: AuditEntry) -> ())?,
	ValidateRuntimeTypes: boolean?,
}

local Policy = {}

local function defaultCanMutate(): boolean
	return true
end

function Policy.createRateLimiter(maxPerSecond: number?)
	if not maxPerSecond or maxPerSecond <= 0 then
		return function(_player: Player): boolean
			return true
		end
	end
	local buckets: { [Player]: { count: number, windowStart: number } } = {}
	return function(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if not bucket or now - bucket.windowStart >= 1 then
			buckets[player] = { count = 1, windowStart = now }
			return true
		end
		if bucket.count >= maxPerSecond then
			return false
		end
		bucket.count += 1
		return true
	end
end

function Policy.buildGuard(
	policy: StorePolicy?,
	storeName: string,
	getPlayer: () -> Player?
): (action: string, path: Path.Path, oldValue: any?, newValue: any?) -> boolean
	local rate = Policy.createRateLimiter(if policy then policy.MutationsPerSecond else nil)
	return function(action: string, path: Path.Path, oldValue: any?, newValue: any?): boolean
		if not policy then
			return true
		end
		local player = getPlayer()
		if not player then
			return true
		end
		if not rate(player) then
			return false
		end
		local can = policy.CanMutate or defaultCanMutate
		if not can(player, action, path, newValue) then
			return false
		end
		if policy.ValidateRuntimeTypes and newValue ~= nil then
			local t = typeof(newValue)
			if t ~= "table" and t ~= "number" and t ~= "string" and t ~= "boolean" then
				return false
			end
		end
		if policy.Audit then
			policy.Audit({
				StoreName = storeName,
				Player = player,
				Action = action,
				Path = path,
				OldValue = oldValue,
				NewValue = newValue,
				Timestamp = os.time(),
			})
		end
		return true
	end
end

return Policy
