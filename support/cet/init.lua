local Cron = require('Cron')
local Ref = require('Ref')

local viewState = {
    isConsoleOpen = false,
    isHotToolsFound = false,
    isTweakXLFound = false,
}

local viewStyle = {
    windowX = 0,
    windowY = 300,
    textMuted = 0xff9f9f9f,
}

local watching = false
local watchedEntities = {}

---@param entity entEntity
local function watchEntity(entity)
    local key = tostring(entity:GetEntityID().hash)

    watchedEntities[key] = {
        name = ('%s#%s'):format(entity:GetClassName().value, key),
        entity = Ref.Weak(entity),
        components = {},
    }

    if not watching then
        Cron.Every(1.0, function()
            for _, entry in pairs(watchedEntities) do
                entry.components = {}
                for index, component in ipairs(RedHotTools.GetComponents(entry.entity)) do
                    table.insert(entry.components, ('%03d name=%q type=%s'):format(index,
                        component:GetName().value, component:GetClassName().value))
                end
            end
        end)
        watching = true
    end
end

---@param entity entEntity
local function forgetEntity(entity)
    local key = tostring(entity:GetEntityID().hash)

    watchedEntities[key] = nil
end

registerForEvent('onInit', function()
    viewState.isHotToolsFound = type(RedHotTools) == 'userdata'
    viewState.isTweakXLFound = type(TweakXL) == 'userdata'

    ---@param this PlayerPuppet
    ObserveAfter('PlayerPuppet', 'OnGameAttached', function(this)
        watchEntity(this)
    end)

    ---@param this PlayerPuppet
    ObserveAfter('PlayerPuppet', 'OnDetach', function(this)
        forgetEntity(this)
    end)

    ---@param this gameuiPuppetPreviewGameController
    ObserveBefore('gameuiPuppetPreviewGameController', 'OnPreviewInitialized', function(this)
        watchEntity(this:GetGamePuppet())
    end)

    ---@param this gameuiPuppetPreviewGameController
    ObserveBefore('gameuiPuppetPreviewGameController', 'OnUninitialize', function(this)
        if this:IsA('gameuiPuppetPreviewGameController') then
            forgetEntity(this:GetGamePuppet())
        end
    end)

    ---@param this PhotoModePlayerEntityComponent
    ObserveAfter('PhotoModePlayerEntityComponent', 'SetupInventory', function(this)
        watchEntity(this.fakePuppet)
    end)

    ---@param this PhotoModePlayerEntityComponent
    ObserveBefore('PhotoModePlayerEntityComponent', 'ClearInventory', function(this)
        forgetEntity(this.fakePuppet)
    end)
end)

registerForEvent('onOverlayOpen', function()
    viewState.isConsoleOpen = true
end)

registerForEvent('onOverlayClose', function()
    viewState.isConsoleOpen = false
end)

registerForEvent('onDraw', function()
    if not viewState.isConsoleOpen or not viewState.isHotToolsFound then
        return
    end

    if not viewStyle.fontSize then
        viewStyle.fontSize = ImGui.GetFontSize()
        viewStyle.viewScale = viewStyle.fontSize / 13
        viewStyle.windowWidth = 400 * viewStyle.viewScale
        viewStyle.windowHeight = 0
        viewStyle.windowPaddingX = 8 * viewStyle.viewScale
        viewStyle.windowPaddingY = 8 * viewStyle.viewScale
        viewStyle.buttonHeight = 24 * viewStyle.viewScale
    end

    ImGui.SetNextWindowPos(viewStyle.windowX, viewStyle.windowY, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(viewStyle.windowWidth + viewStyle.windowPaddingX * 2 - 1, viewStyle.windowHeight)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, viewStyle.windowPaddingX, viewStyle.windowPaddingY)

    if ImGui.Begin('Red Hot Tools', ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse) then
        ImGui.BeginTabBar('Red Hot Tools TabBar')

		if ImGui.BeginTabItem(' Reload ') then
            if viewState.isHotToolsFound then
                ImGui.Text('Archives')
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.textMuted)
                ImGui.TextWrapped(
                    'Hot load archives from archive/pc/hot.\n' ..
                    'New archives will be moved to archive/pc/mod and loaded.\n' ..
                    'Existing archives will be unloaded and replaced.')
                ImGui.PopStyleColor()
                ImGui.Spacing()

                ImGui.Checkbox('Watch for changes', true)

                if ImGui.Button('Reload archives', viewStyle.windowWidth, viewStyle.buttonHeight) then
                    RedHotTools.ReloadArchives()
                end

                ImGui.Spacing()
                ImGui.Separator()
                ImGui.Spacing()

                ImGui.Text('Scripts')
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.textMuted)
                ImGui.TextWrapped('Hot load scripts from r6/scripts.')
                ImGui.PopStyleColor()
                ImGui.Spacing()

                if ImGui.Button('Reload scripts', viewStyle.windowWidth, viewStyle.buttonHeight) then
                    RedHotTools.ReloadScripts()
                end
            end

            if viewState.isTweakXLFound then
                ImGui.Spacing()
                ImGui.Separator()
                ImGui.Spacing()

                ImGui.Text('Tweaks')
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.textMuted)
                ImGui.TextWrapped('Hot load tweaks from r6/tweaks and scriptable tweaks.')
                ImGui.PopStyleColor()
                ImGui.Spacing()

                if ImGui.Button('Reload tweaks', viewStyle.windowWidth, viewStyle.buttonHeight) then
                    TweakXL.Reload()
                end
            end

			ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem(' Inspect ') then
            ImGui.Spacing()
            if watching then
                ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
                ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
                ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)
                --ImGui.BeginChildFrame(1, 0, 300)

                for _, entry in pairs(watchedEntities) do
                    if ImGui.CollapsingHeader(entry.name) then
                        local text = table.concat(entry.components, '\n')
                        ImGui.PushItemWidth(-1)
                        ImGui.InputTextMultiline('##' .. entry.name, text, text:len(), 0, 0, ImGuiInputTextFlags.ReadOnly)
                        ImGui.PopItemWidth()
                    end
                end

                --ImGui.EndChildFrame()
                ImGui.PopStyleColor()
                ImGui.PopStyleVar(2)
            else
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.textMuted)
                ImGui.TextWrapped('No entities to inspect.')
                ImGui.PopStyleColor()
            end
        end
    end

    ImGui.End()
    ImGui.PopStyleVar()
end)

registerForEvent('onUpdate', function(delta)
	Cron.Update(delta)
end)
