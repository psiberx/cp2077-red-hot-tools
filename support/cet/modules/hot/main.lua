local app, moduleID, modulePath = ...

-- Deps --

local PersistentState = require('libs/PersistentState')
local Enumeration = require('libs/Enumeration')
local ImGuiEx = require('libs/ImGuiEx')

-- User State --

local MainTab = Enumeration('None', 'Archives', 'Scripts', 'Tweaks')

local userState = {}
local userStateSchema = {
    isModuleActive = { type = 'boolean', default = true },
    selectedTab = { type = MainTab, default = MainTab.Inspect },
}

local function initializeUserState()
    PersistentState.Initialize(userState, modulePath .. '/.state', userStateSchema)
end

local function saveUserState()
    PersistentState.Flush(userState)
end

-- Hot Reload --

local function reloadArchives()
    RedHotTools.ReloadArchives()
end

local function reloadTweaks()
    --RedHotTools.ReloadTweaks()
    if TweakXL then
        TweakXL.Reload()
    end
end

local function reloadScripts()
    RedHotTools.ReloadScripts()
end

local function collectGarbage()
    collectgarbage()
end

-- GUI --

local viewState = {
    isFirstOpen = true,
    isConsoleOpen = false,
    isWindowOpen = true,
    isWindowExpanded = true,
}

local viewStyle = {
    labelTextColor = 0xFF9F9F9F,
    mutedTextColor = 0xFFA5A19B,
    dangerTextColor = 0xFF6666FF,
    disabledButtonColor = 0xFF4F4F4F,
}

local function initializeViewStyle()
    if not viewStyle.fontSize then
        viewStyle.fontSize = ImGui.GetFontSize()
        viewStyle.viewScale = viewStyle.fontSize / 13

        local screenX, screenY = GetDisplayResolution()

        viewStyle.windowPaddingX = 8 * viewStyle.viewScale
        viewStyle.windowPaddingY = viewStyle.windowPaddingX
        viewStyle.windowWidth = 340 * viewStyle.viewScale
        viewStyle.windowFullWidth = viewStyle.windowWidth + viewStyle.windowPaddingX * 2 - 1
        viewStyle.windowHeight = 0
        viewStyle.windowDefaultX = (screenX - viewStyle.windowFullWidth - 4) / 2
        viewStyle.windowDefaultY = (screenY - 100) / 2

        viewStyle.mainWindowFlags = ImGuiWindowFlags.NoResize
            + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse

        viewStyle.buttonHeight = 21 * viewStyle.viewScale
    end
end

local function drawArchivesContent()
    ImGui.Text('File System Watcher')
    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.TextWrapped(
        'Watches "archive/pc/hot" and hot loads placed archives.\n' ..
        'Existing archives are replaced in "archive/pc/mod" and "mods/*/archives".\n' ..
        'New archives are moved to "archive/pc/mod" and loaded.')
    ImGui.PopStyleColor()
    ImGui.Text('Status:')
    ImGui.SameLine()
    ImGui.PushStyleColor(ImGuiCol.Text, 0xcc00ff00)
    ImGui.Text('Active')
    ImGui.PopStyleColor()

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.Text('WolvenKit Integration')
    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.TextWrapped('Press "Hot Reload" button in WolvenKit to pack & hot reload current project.')
    ImGui.PopStyleColor()

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.Text('Manual Control')
    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.TextWrapped('Hot reload archive extensions from "archive/pc/mod" and "mods/*/archives".')
    ImGui.PopStyleColor()
    ImGui.Spacing()

    if ImGui.Button('Reload extensions', viewStyle.windowWidth, viewStyle.buttonHeight) then
        reloadArchives()
    end
end

local function drawScriptsContent()
    ImGui.Text('VS Code Integration')
    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.TextWrapped('Run "Hot Reload Scripts" command from VS Code to hot reload all scripts.')
    ImGui.PopStyleColor()

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.Text('Manual Control')
    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.TextWrapped('Hot reload scripts from "r6/scripts".')
    ImGui.PopStyleColor()
    ImGui.Spacing()

    if ImGui.Button('Reload scripts', viewStyle.windowWidth, viewStyle.buttonHeight) then
        reloadScripts()
    end
end

local function drawTweaksContent()
    ImGui.Text('VS Code Integration')
    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.TextWrapped('Run "Hot Reload Tweaks" command from VS Code to hot reload all tweaks.')
    ImGui.PopStyleColor()

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.Text('Manual Control')
    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.TextWrapped('Hot reload tweaks from "r6/tweaks" and scriptable tweaks.')
    ImGui.PopStyleColor()
    ImGui.Spacing()

    if ImGui.Button('Reload tweaks', viewStyle.windowWidth, viewStyle.buttonHeight) then
        reloadTweaks()
    end
end

local function drawMainWindow()
    ImGui.SetNextWindowPos(viewStyle.windowDefaultX, viewStyle.windowDefaultY, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(viewStyle.windowFullWidth, viewStyle.windowHeight)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, viewStyle.windowPaddingX, viewStyle.windowPaddingY)

    viewState.isWindowOpen = ImGuiEx.Begin('Hot Reload##RHT:HotReload', app.canCloseTools(), viewStyle.mainWindowFlags)
    viewState.isWindowExpanded = not ImGui.IsWindowCollapsed()

    if viewState.isWindowOpen and viewState.isWindowExpanded then
        app.drawSharedMenu(moduleID)

        ImGui.BeginTabBar('##RHT:HotReloadTabBar')

        local selectedTab
        local featureTabs = {
            { id = MainTab.Archives, draw = drawArchivesContent },
            { id = MainTab.Scripts, draw = drawScriptsContent },
            { id = MainTab.Tweaks, draw = drawTweaksContent },
        }

        for _, featureTab in ipairs(featureTabs) do
            local tabLabel = ' ' .. featureTab.id .. ' '
            local tabFlags = ImGuiTabItemFlags.None
            if viewState.isFirstOpen and userState.selectedTab == featureTab.id then
                tabFlags = ImGuiTabItemFlags.SetSelected
            end

            if ImGui.BeginTabItem(tabLabel, tabFlags) then
                selectedTab = featureTab.id
                ImGui.Spacing()
                featureTab.draw()
                ImGui.EndTabItem()
            end
        end

        userState.selectedTab = selectedTab
        viewState.isFirstOpen = false
    end

    ImGui.End()
    ImGui.PopStyleVar()

    if not viewState.isWindowOpen then
        userState.isModuleActive = false
        saveUserState()
    end
end

-- Module --

local function isActive()
    return userState.isModuleActive
end

local function setActive(active)
    userState.isModuleActive = active
    saveUserState()
end

local function onInit()
    initializeUserState()
end

local function onShutdown()
    saveUserState()
end

local function onOverlayOpen()
    viewState.isConsoleOpen = true
end

local function onOverlayClose()
    viewState.isConsoleOpen = false
    saveUserState()
end

local function onDraw()
    if not userState.isModuleActive then
        return
    end

    if not viewState.isConsoleOpen then
        return
    end

    initializeViewStyle()
    drawMainWindow()
end

return {
    events = {
        onInit = onInit,
        onShutdown = onShutdown,
        onOverlayOpen = onOverlayOpen,
        onOverlayClose = onOverlayClose,
        onDraw = onDraw,
    },
    tools = {
        { id = 'HotReload', label = 'Hot Reload', isActive = isActive, setActive = setActive }
    },
    actions = {
        { id = 'ReloadArchives', label = 'Reload ArchiveXL extensions', callback = reloadArchives },
        { id = 'ReloadTweaks', label = 'Reload TweakXL tweaks', callback = reloadTweaks },
        { id = 'ReloadScripts', label = 'Reload Redscript scripts', callback = reloadScripts },
        { id = 'CollectGarbage', label = 'Recycle game object refs', callback = collectGarbage },
    },
}
