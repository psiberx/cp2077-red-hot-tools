local PersistentState = {}

local stateFilePath
local stateDataRef

local function exportStateData(t, max, depth, result)
	if type(t) ~= 'table' then
		return ''
	end

	max = max or 63
	depth = depth or 0

	local indent = string.rep('\t', depth)
	local output = result or {}

	table.insert(output, '{\n')

	for k, v in pairs(t) do
		local ktype = type(k)
		local vtype = type(v)

		local kstr = ''
		if ktype == 'string' then
			kstr = string.format('[%q] = ', k)
		end

		local vstr = ''
		if vtype == 'string' then
			vstr = string.format('%q', v)
		elseif vtype == 'table' then
			if depth < max then
				exportStateData(v, max, depth + 1, output)
			end
		elseif vtype == 'userdata' then
			vstr = tostring(v)
			if vstr:find('^userdata:') or vstr:find('^sol%.') then
				vstr = ''
			end
		elseif vtype == 'function' or vtype == 'thread' then
			vstr = ''
		else
			vstr = tostring(v)
		end

		if vstr ~= '' then
			table.insert(output, string.format('\t%s%s%s,\n', indent, kstr, vstr))
		end
	end

	if not result and #output == 1 then
		return '{}'
	end

	table.insert(output, indent .. '}')

	if not result then
		return table.concat(output)
	end
end

function PersistentState.Initialize(filePath, dataRef, dataSchema)
	stateFilePath = filePath
	stateDataRef = dataRef

	local chunk = loadfile(filePath)
	if type(chunk) == 'function' then
        for k, v in pairs(chunk()) do
            stateDataRef[k] = v
        end
	end

    for field, schema in pairs(dataSchema) do
        if type(schema.type) == 'string' then
            if type(stateDataRef[field]) ~= schema.type then
                stateDataRef[field] = schema.default
            end
        elseif type(schema.type) == 'table' then
            if schema.type[stateDataRef[field]] ~= stateDataRef[field] then
                stateDataRef[field] = schema.default
            end
        end
    end
end

function PersistentState.Flush()
	local stateFile = io.open(stateFilePath, 'w')
	if stateFile ~= nil then
		stateFile:write('return ' .. exportStateData(stateDataRef))
		stateFile:close()
	end
end

return PersistentState
