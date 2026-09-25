--!strict

export type MigrationStep = {
	Version: number,
	Up: (data: any) -> any,
}

export type MigrationOptions = {
	TemplateVersion: number,
	Migrations: { MigrationStep }?,
	MetaPath: { string }?,
}

local DEFAULT_META = { "_DataService", "TemplateVersion" }

local function readMeta(data: any, metaPath: { string }): number
	local cursor = data
	for _, segment in metaPath do
		if type(cursor) ~= "table" then
			return 0
		end
		cursor = cursor[segment]
	end
	if type(cursor) == "number" then
		return cursor
	end
	return 0
end

local function writeMeta(data: any, metaPath: { string }, version: number)
	local cursor = data
	for i = 1, #metaPath - 1 do
		local segment = metaPath[i]
		if type(cursor[segment]) ~= "table" then
			cursor[segment] = {}
		end
		cursor = cursor[segment]
	end
	cursor[metaPath[#metaPath]] = version
end

local Migration = {}

function Migration.run(data: any, options: MigrationOptions): any
	local metaPath = options.MetaPath or DEFAULT_META
	local current = readMeta(data, metaPath)
	local target = options.TemplateVersion
	if current >= target then
		return data
	end

	local steps = options.Migrations or {}
	table.sort(steps, function(a, b)
		return a.Version < b.Version
	end)

	for _, step in steps do
		if step.Version > current and step.Version <= target then
			data = step.Up(data)
			current = step.Version
			writeMeta(data, metaPath, current)
		end
	end

	writeMeta(data, metaPath, target)
	return data
end

return Migration
