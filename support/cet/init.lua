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
    table.insert(hotkeys, hotkey)
end

local function activateHotkeys()
    for _, hotkey in ipairs(hotkeys) do
        registerHotkey(hotkey.id, hotkey.label, function()
            if isPluginFound then
                hotkey.callback()
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

local viewData = {}
local viewStyle = {}

local function initializeViewStyle()
    if not viewStyle.fontSize then
        viewStyle.fontSize = ImGui.GetFontSize()
        viewStyle.viewScale = viewStyle.fontSize / 13

        --local screenX, screenY = GetDisplayResolution()
        --
        --viewStyle.aboutPaddingX = 8 * viewStyle.viewScale
        --viewStyle.aboutPaddingY = viewStyle.aboutPaddingX
        --viewStyle.aboutWidth = 250 * viewStyle.viewScale
        --viewStyle.aboutHeight = 150
        --viewStyle.aboutFullWidth = viewStyle.aboutWidth + viewStyle.aboutPaddingX * 2 - 1
        --viewStyle.aboutFullHeight = viewStyle.aboutHeight + viewStyle.aboutPaddingY * 2 - 1
        --viewStyle.aboutPositionX = (screenX - viewStyle.aboutFullWidth - 4) / 2
        --viewStyle.aboutPositionY = (screenY - viewStyle.aboutFullHeight - 4) / 2
        --viewStyle.aboutFlags = ImGuiWindowFlags.NoCollapse + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove

        viewStyle.buttonHeight = 21 * viewStyle.viewScale
    end
end

local function initializeViewData()
    viewData.pluginVersion = RedHotTools.Version()
    viewData.guiVersion = loadfile('version.lua')()
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

function privateApi.drawMainMenu()
    --local openAboutPopup = false

    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu('Actions') then
            for _, action in ipairs(actions) do
                if ImGui.MenuItem(action.label) then
                    action.callback()
                end
            end
            ImGui.EndMenu()
        end

        if ImGui.BeginMenu('Tools') then
            for _, tool in ipairs(tools) do
                local active = tool.isActive()
                local _, clicked = ImGui.MenuItem(tool.label, '', active)
                if clicked then
                    tool.setActive(not active)
                end
            end
            ImGui.EndMenu()
        end

        if ImGui.BeginMenu('About') then
            ImGui.Text('Red Hot Tools')
            ImGui.Text('Plugin Version: ' .. viewData.pluginVersion)
            ImGui.Text('GUI Version: ' .. viewData.guiVersion)
            ImGui.EndMenu()
        end

        --if ImGui.BeginMenu('Help') then
        --    if ImGui.MenuItem('About', '', false, false) then
        --        openAboutPopup = true
        --    end
        --    ImGui.EndMenu()
        --end

        ImGui.EndMenuBar()
    end

    --if openAboutPopup then
    --    ImGui.OpenPopup('Red Hot Tools##RHT:About')
    --    ImGui.SetNextWindowPos(viewStyle.aboutPositionX, viewStyle.aboutPositionY, ImGuiCond.Always)
    --    ImGui.SetNextWindowSize(viewStyle.aboutFullWidth, viewStyle.aboutFullHeight)
    --end
    --
    --if ImGui.BeginPopupModal('Red Hot Tools##RHT:About', true, viewStyle.aboutFlags) then
    --    ImGui.Text('About')
    --    if ImGui.Button('Close') then
    --        ImGui.CloseCurrentPopup()
    --    end
    --    ImGui.EndPopup()
    --end
end

function privateApi.drawHotkeys(module)

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
    --'modules/ink',
    'modules/hot',
})

activateEvents()
activateHotkeys()

return publicApi
