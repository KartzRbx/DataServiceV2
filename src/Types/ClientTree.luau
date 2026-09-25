--!strict

-- Path tree with excluded root keys (replicated client view).

type function ClientTreeOf(templateType: type, excludeRoot: type): type
	local excluded: { [string]: boolean } = {}

	if excludeRoot:is("table") then
		local indexer = excludeRoot:indexer()
		if indexer and indexer.result:is("singleton") then
			excluded[tostring(indexer.result:value())] = true
		end
		for key in excludeRoot:properties() do
			if key:is("singleton") then
				excluded[tostring(key:value())] = true
			end
		end
	elseif excludeRoot:is("union") then
		for _, component in excludeRoot:components() do
			if component:is("singleton") then
				excluded[tostring(component:value())] = true
			end
		end
	elseif excludeRoot:is("singleton") then
		excluded[tostring(excludeRoot:value())] = true
	end

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
		if valueType:is("any") or valueType:is("unknown") then
			return types.newtable()
		end
		if not valueType:is("table") then
			local token = types.newtable()
			token:setproperty("__pathValue", valueType)
			return token
		end
		local mapped = types.newtable()
		for key in valueType:properties() do
			if key:is("singleton") then
				local name = tostring(key:value())
				if excluded[name] then
					-- skip excluded root keys
				else
					local child = valueType:readproperty(key)
					if child then
						mapped:setproperty(key, mapValue(unwrapOptional(child)))
					end
				end
			else
				local child = valueType:readproperty(key)
				if child then
					mapped:setproperty(key, mapValue(unwrapOptional(child)))
				end
			end
		end
		return mapped
	end

	if templateType:is("any") or templateType:is("unknown") or templateType:is("never") then
		return types.any
	end
	return mapValue(templateType)
end

export type ClientTree<T, ExcludeRoot> = ClientTreeOf<T, ExcludeRoot>

type _anchor = ClientTreeOf<{ Public: number, Private: number }, "Private">

return {}
