local function opacity(abgr)
    return bit32.band(bit32.rshift(abgr, 24), 0xFF)
end

local function fade(abgr, a)
    return bit32.bor(bit32.lshift(bit32.band(a, 0xFF), 24), bit32.band(abgr, 0xFFFFFF))
end

local function sanitizeInputText(text)
    return text:gsub('`', '')
end

local function buildComboOptions(values, capitalize)
    local options = {}
    for index, value in ipairs(values) do
        options[index] = value:gsub('([a-z])([A-Z])', function(l, u)
            return l .. ' ' .. (capitalize and u or u:lower())
        end)
    end
    return options
end

local function buildEnumOptions(enumType)
    local options = {}
    local value = 0
    while true do
        local instance = Enum.new(enumType, value)
        if EnumInt(instance) ~= value then
            break
        end

        table.insert(options, instance.value)
        value = value + 1

        if value > 256 then
            break
        end
    end
    return options
end

local function beginWindow(title, closable, flags)
    if closable then
        return ImGui.Begin(title, true, flags)
    else
        ImGui.Begin(title, flags)
        return true
    end
end

return {
    Begin = beginWindow,
    BuildComboOptions = buildComboOptions,
    BuildEnumOptions = buildEnumOptions,
    SanitizeInputText = sanitizeInputText,
    Opacity = opacity,
    Fade = fade,
}
