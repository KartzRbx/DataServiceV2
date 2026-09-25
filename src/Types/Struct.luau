--!strict

type function DeepPartialOf(t: type): type
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

	local function mapValue(valueType: type): type
		valueType = unwrapOptional(valueType)
		if valueType:is("any") or valueType:is("unknown") or valueType:is("never") then
			return types.any
		end
		if not valueType:is("table") then
			return types.optional(valueType)
		end
		local out = types.newtable()
		for key, prop in valueType:properties() do
			local value = prop.read or prop.write
			if value ~= nil then
				out:setproperty(key, mapValue(value))
			end
		end
		local indexer = valueType:indexer()
		if indexer then
			out:setindexer(indexer.index, mapValue(indexer.readresult))
		end
		return out
	end

	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[DeepPartial] expected a table, got {t.tag}`)
	end
	return mapValue(t)
end

export type DeepPartial<T> = DeepPartialOf<T>

type _anchor = DeepPartialOf<{ a: number, b: { c: string } }>

return {}
