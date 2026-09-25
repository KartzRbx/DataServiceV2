--!strict
-- Signal-shaped leaves for reactive path trees (V3).

export type Signal<T> = {
	Connect: (self: Signal<T>, callback: (newValue: T, oldValue: T) -> ()) -> RBXScriptConnection,
	Once: (self: Signal<T>, callback: (newValue: T, oldValue: T) -> ()) -> RBXScriptConnection,
}

type function SignalsOf(templateType: type): type
	local function unwrapOptional(valueType: type): type
		if not valueType:is("union") then
			return valueType
		end
		local resolved = nil
		for _, component in valueType:components() do
			if not (component:is("singleton") and component:value() == nil) then
				resolved = if resolved then types.unionof(resolved, component) else component
			end
		end
		return resolved or valueType
	end

	local function signalType(valueType: type): type
		local sig = types.newtable()
		local connect = types.newfunction(
			{ head = { sig } },
			{ head = { types.newfunction({ head = { valueType, valueType } }, { head = {} }) } }
		)
		sig:setproperty(types.singleton("Connect"), connect)
		return sig
	end

	local function mapValue(valueType: type): type
		valueType = unwrapOptional(valueType)

		if valueType:is("any") or valueType:is("unknown") then
			return types.newtable()
		end

		if valueType:is("union") then
			for _, component in valueType:components() do
				if component:is("table") then
					return mapValue(component)
				end
			end
			return types.newtable()
		end

		if not valueType:is("table") then
			return signalType(valueType)
		end

		local mapped = types.newtable()
		local hasMembers = false

		for key in valueType:properties() do
			local childType = valueType:readproperty(key)
			if childType then
				mapped:setproperty(key, mapValue(unwrapOptional(childType)))
				hasMembers = true
			end
		end

		local indexerInfo = valueType:indexer()
		if indexerInfo then
			mapped:setindexer(indexerInfo.index, mapValue(indexerInfo.readresult))
			hasMembers = true
		end

		if hasMembers then
			return mapped
		end

		return signalType(valueType)
	end

	return mapValue(templateType)
end

export type MapToSignals<T> = SignalsOf<T>

type _anchor = MapToSignals<{ Coins: number, Nested: { XP: number } }>

return {}
