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

registerForEvent('onInit', function()
    viewState.isHotToolsFound = type(RedHotTools) == 'userdata'
    viewState.isTweakXLFound = type(TweakXL) == 'userdata'

    viewStyle.fontSize = ImGui.GetFontSize()
    viewStyle.viewScale = viewStyle.fontSize / 13
    viewStyle.windowWidth = 400 * viewStyle.viewScale
    viewStyle.windowHeight = 0
    viewStyle.windowPaddingX = 8 * viewStyle.viewScale
    viewStyle.windowPaddingY = 8 * viewStyle.viewScale
    viewStyle.buttonHeight = 24 * viewStyle.viewScale
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

    ImGui.SetNextWindowPos(viewStyle.windowX, viewStyle.windowY, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(viewStyle.windowWidth + viewStyle.windowPaddingX * 2 - 1, viewStyle.windowHeight)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, viewStyle.windowPaddingX, viewStyle.windowPaddingY)

    if ImGui.Begin('Red Hot Tools', ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse) then
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
    end

    ImGui.End()
    ImGui.PopStyleVar()
end)
