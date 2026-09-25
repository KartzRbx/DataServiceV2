--!strict

local Path = require(script.Parent.Path)

local Watch = {}

export type Watcher = {
	Disconnect: (self: Watcher) -> (),
}

-- Reactive helper: connects to GetChangedSignal for a typed path.
function Watch.path<V>(data: any, path: Path.PathToken<V>, callback: (newValue: V, oldValue: V) -> ()): Watcher
	local conn = data:GetChangedSignal(path):Connect(callback)
	return {
		Disconnect = function()
			conn:Disconnect()
		end,
	}
end

return Watch
