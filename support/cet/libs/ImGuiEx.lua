local function opacity(abgr)
    return bit32.band(bit32.rshift(abgr, 24), 0xFF)
end

local function fade(abgr, a)
    return bit32.bor(bit32.lshift(bit32.band(a, 0xFF), 24), bit32.band(abgr, 0xFFFFFF))
end

local function sanitizeInputText(text)
    return text:gsub('`', '')
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
    SanitizeInputText = sanitizeInputText,
    Opacity = opacity,
    Fade = fade,
}
