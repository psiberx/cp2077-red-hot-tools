-- Deps --

local Cron = require('libs/Cron')

-- API --

local publicApi = {}
local privateApi = {}

-- Plugin --

local isPluginFound = false

local function detectPlugin()
    isPluginFound = type(RedHotTools) == 'userdata'
    return isPluginFound
end

function publicApi.IsActive()
    return isPluginFound
end

-- Events --

local events = {
    onInit = {},
    onUpdate = {},
    onShutdown = {},
    onOverlayOpen = {},
    onOverlayClose = {},
    onDraw = {},
}

local function addEventCallback(event, callback)
    table.insert(events[event], callback)
end

local function removeEventCallback(event, callback)
    for i, callback_ in ipairs(events[event]) do
        if callback == callback_ then
            table.remove(events[event], i)
            break
        end
    end
end

local function fireEventCallbacks(event, ...)
    for _, callback in ipairs(events[event]) do
        callback(...)
    end
end

local function activateEvents()
    for event, callbacks in pairs(events) do
        if #callbacks > 0 then
            registerForEvent(event, function(...)
                fireEventCallbacks(event, ...)
            end)
        end
    end
end

local function deactivateEvents()
    for event, _ in pairs(events) do
        events[event] = {}
    end
end

-- Hotkeys --

local hotkeys = {}

local function addHotkey(hotkey)
    if not hotkeys[hotkey.id] then
        hotkeys[hotkey.id] = {
            id = hotkey.id,
            group = hotkey.group,
            label = hotkey.label,
            callbacks = {},
        }

    end

    hotkeys[hotkey.id].callbacks[hotkey.module] = hotkey.callback

    table.insert(hotkeys, hotkeys[hotkey.id])
    for i = #hotkeys - 1, 1, -1 do
        if hotkeys[i].id == hotkey.id then
            table.remove(hotkeys, i)
            break
        end
    end
end

local function getHotkeys(module)
    if not module then
        return hotkeys
    end

    local filtered = {}
    for _, hotkey in ipairs(hotkeys) do
        if hotkey.callbacks[module] then
            table.insert(filtered, hotkey)
        end
    end
    return filtered
end

local function activateHotkeys()
    for _, hotkey in ipairs(hotkeys) do
        registerHotkey(hotkey.id, hotkey.group .. ': ' .. hotkey.label, function()
            if isPluginFound then
                for _, callback in pairs(hotkey.callbacks) do
                    callback()
                end
            end
        end)
    end
end

-- Tools --

local tools = {}

local function addTool(tool)
    table.insert(tools, tool)
end

-- Actions --

local actions = {}

local function addAction(action)
    table.insert(actions, action)
end

-- GUI --

local viewState = {
    menuAnchorHovered = {}
}

local viewStyle = {
    mutedTextColor = 0xFFA5A19B,
    menuSectionLabelColor = 0xFFA5A19B,
    menuSectionLabelSize = 0.75,
}

local function initializeViewStyle()
    if not viewStyle.fontSize then
        viewStyle.fontSize = ImGui.GetFontSize()
        viewStyle.viewScale = viewStyle.fontSize / 13
        viewStyle.doubleFontSize = viewStyle.fontSize * 2.0
        viewStyle.halfFontSize = viewStyle.fontSize / 2.0
    end
end

local function initializeViewData()
    viewState.pluginVersion = RedHotTools.Version()
    viewState.guiVersion = loadfile('version.lua')()
end

function privateApi.canCloseTools()
    local activeWindows = 0

    for _, tool in ipairs(tools) do
        if tool.isActive() then
            if activeWindows == 0 then
                activeWindows = activeWindows + 1
            else
                return true
            end
        end
    end

    return false
end

function privateApi.drawSharedMenu(module)
    local regionW = ImGui.GetContentRegionAvail()
    local cursorX, cursorY = ImGui.GetCursorPos()

    ImGui.SetCursorPosX(cursorX + regionW - viewStyle.doubleFontSize + 1)
    ImGui.BeginGroup()
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
    if viewState.menuAnchorHovered[module] then
        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(ImGuiCol.ButtonHovered, 1))
    end
    ImGui.Bullet()
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() - viewStyle.halfFontSize + 1)
    ImGui.Bullet()
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() - viewStyle.halfFontSize + 1)
    ImGui.Bullet()
    if viewState.menuAnchorHovered[module] then
        viewState.menuAnchorHovered[module] = nil
        ImGui.PopStyleColor()
    end
    ImGui.PopStyleVar()
    ImGui.EndGroup()
    viewState.menuAnchorHovered[module] = ImGui.IsItemHovered()
    ImGui.SetCursorPos(cursorX, cursorY)

    if ImGui.BeginPopupContextItem('##SharedMenu', ImGuiPopupFlags.MouseButtonLeft) then
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.menuSectionLabelColor)
        ImGui.SetWindowFontScale(viewStyle.menuSectionLabelSize)
        ImGui.Text('TOOLS')
        ImGui.SetWindowFontScale(1.0)
        ImGui.PopStyleColor()

        for _, tool in ipairs(tools) do
            local active = tool.isActive()
            local _, clicked = ImGui.MenuItem(tool.label, '', active)
            if clicked then
                tool.setActive(not active)
            end
        end

        local filtered = {}
        for _, action in ipairs(actions) do
            if action.module ~= module then
                table.insert(filtered, action)
            end
        end

        if #filtered > 0 then
            ImGui.Separator()
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.menuSectionLabelColor)
            ImGui.SetWindowFontScale(viewStyle.menuSectionLabelSize)
            ImGui.Text('QUICK ACTIONS')
            ImGui.SetWindowFontScale(1.0)
            ImGui.PopStyleColor()
            --local group
            for _, action in ipairs(filtered) do
                --if group ~= action.module then
                --    group = action.module
                --end
                if ImGui.MenuItem(action.label) then
                    action.callback()
                end
            end
        end

        ImGui.Separator()

        if ImGui.BeginMenu('About') then
            ImGui.Text('Red Hot Tools')
            ImGui.Text('Plugin Version: ' .. viewState.pluginVersion)
            ImGui.Text('GUI Version: ' .. viewState.guiVersion)
            ImGui.EndMenu()
        end

        ImGui.EndPopup()
    end
end

function privateApi.drawHotkeys(module)
    ImGui.TextWrapped('Hotkeys are configured in Cyber Engine Tweaks > Bindings.')

    ImGui.BeginTable('##Hotkeys', 2)

    local group
    for _, hotkey in ipairs(getHotkeys(module)) do
        if group ~= hotkey.group then
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.menuSectionLabelColor)
            ImGui.SetWindowFontScale(viewStyle.menuSectionLabelSize)
            ImGui.Text(hotkey.group:upper())
            ImGui.SetWindowFontScale(1.0)
            ImGui.PopStyleColor()
            ImGui.TableNextColumn()
            ImGui.Spacing()
            ImGui.Separator()
            group = hotkey.group
        end

        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        ImGui.Text(hotkey.label)
        ImGui.TableNextColumn()
        if IsBound(hotkey.id) then
            ImGui.Text(GetBind(hotkey.id))
        else
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
            ImGui.Text('(not set)')
            ImGui.PopStyleColor()
        end
    end

    ImGui.EndTable()
end

-- Modules --

local modules = {}

local function loadModules(paths)
    for _, path in ipairs(paths) do
        local module = loadfile(path .. '/main.lua')(privateApi, path)

        if module.events then
            for event, _ in pairs(events) do
                if module.events[event] then
                    addEventCallback(event, module.events[event])
                end
            end
        end

        if module.tools then
            for _, tool in ipairs(module.tools) do
                tool.module = module.id
                addTool(tool)
            end
        end

        if module.actions then
            for _, action in ipairs(module.actions) do
                action.module = module.id
                addAction(action)
            end
        end

        if module.hotkeys then
            for _, hotkey in ipairs(module.hotkeys) do
                hotkey.module = module.id
                addHotkey(hotkey)
            end
        end

        if module.privateApi then
            for name, callback in pairs(module.privateApi) do
                if not privateApi[name] then
                    privateApi[name] = callback
                end
            end
        end

        if module.publicApi then
            for name, callback in pairs(module.publicApi) do
                if not publicApi[name] then
                    publicApi[name] = callback
                end
            end
        end

        table.insert(modules, module)
    end
end

-- Extensions --

local extensions = {}

function privateApi.getRegisteredExtensions()
    return extensions
end

function publicApi.RegisterExtension(plugin)
    table.insert(extensions, plugin)
    return true
end

-- Migration --

os.remove('.state')
os.remove('Cron.lua')
os.remove('PersistentState.lua')
os.remove('Ref.lua')

-- Bootstrap --

addEventCallback('onInit', function()
    if detectPlugin() then
        initializeViewData()
    else
        deactivateEvents()
    end
end)

addEventCallback('onDraw', initializeViewStyle)
addEventCallback('onDraw', function()
    removeEventCallback('onDraw', initializeViewStyle)
end)

addEventCallback('onUpdate', Cron.Update)

loadModules({
    'modules/world',
    'modules/ink',
    'modules/hot',
})

activateEvents()
activateHotkeys()

return publicApi
