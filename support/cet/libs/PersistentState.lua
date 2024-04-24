local PersistentState = {}

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
		if not k:find('^_') then
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
	end

	if not result and #output == 1 then
		return '{}'
	end

	table.insert(output, indent .. '}')

	if not result then
		return table.concat(output)
	end
end

local function getValue(value)
    if type(value) == 'function' then
        return value()
    end
    return value
end

function PersistentState.Initialize(state, filePath, dataSchema)
	state._filePath = filePath
	state._dataSchema = dataSchema

	local chunk = loadfile(filePath)
	if type(chunk) == 'function' then
        for k, v in pairs(chunk()) do
            if dataSchema[k] then
                state[k] = v
            end
        end
	end

    for field, schema in pairs(dataSchema) do
        if type(schema.type) == 'string' then
            if state[field] == nil or type(state[field]) ~= schema.type then
                state[field] = getValue(schema.default)
            end
        elseif type(schema.type) == 'table' then
            if state[field] == nil or schema.type[state[field]] ~= state[field] then
                state[field] = getValue(schema.default)
            end
        end
    end

    return state
end

function PersistentState.Flush(state)
	if state and state._filePath then
        local stateFile = io.open(state._filePath, 'w')
        if stateFile ~= nil then
            stateFile:write('return ' .. exportStateData(state))
            stateFile:close()
        end
    end
end

return PersistentState
