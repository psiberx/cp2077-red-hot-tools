local PersistentState = {}

local function exportStateData(input, max, depth, output, schema)
	if type(input) ~= 'table' then
		return ''
	end

    if not output then
        output = {}
    end

    if not schema then
        schema = output._schema or input._schema
    end

	max = max or 63
	depth = depth or 0

	table.insert(output, '{\n')

	local indent = string.rep('\t', depth)

	for k, v in pairs(input) do
		if type(k) == 'string' and k:find('^_') then
		    goto continue
		end

		if schema and not schema[k] then
		    goto continue
		end

        local ktype = type(k)
        local vtype = type(v)

        local kstr = ''
        if ktype == 'string' then
            kstr = string.format('[%q] = ', k)
        elseif ktype == 'number' then
            kstr = string.format('[%d] = ', k)
        end

        local vstr = ''
        if vtype == 'string' then
            vstr = string.format('%q', v)
        elseif vtype == 'table' then
            if depth < max then
                vstr = exportStateData(v, max, depth + 1)
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

        ::continue::
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

function PersistentState.Initialize(state, filePath, schema)
	state._filePath = filePath
	state._schema = schema

	local chunk = loadfile(filePath)
	if type(chunk) == 'function' then
        local data = chunk()
        if type(data) == 'table' then
            for k, v in pairs(data) do
                if schema[k] then
                    state[k] = v
                end
            end
        end
	end

    for field, def in pairs(schema) do
        if type(def.type) == 'string' then
            if state[field] == nil or type(state[field]) ~= def.type then
                state[field] = getValue(def.default)
            end
        elseif type(def.type) == 'table' then
            if state[field] == nil or def.type[state[field]] ~= state[field] then
                state[field] = getValue(def.default)
            end
        else
            if state[field] == nil then
                state[field] = getValue(def.default)
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
