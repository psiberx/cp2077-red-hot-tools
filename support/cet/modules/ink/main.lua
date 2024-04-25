local app, modulePath = ...
local moduleID = 'InkTools'

-- Deps --

local Cron = require('libs/Cron')
local PersistentState = require('libs/PersistentState')
local Enumeration = require('libs/Enumeration')
local ImGuiEx = require('libs/ImGuiEx')

-- Game Systems --

local inspectionSystem

local function initializeSystems()
    inspectionSystem = Game.GetInspectionSystem()
end

-- User State --

local MainTab = Enumeration('None', 'Inspect', 'Pick', 'Settings', 'Hotkeys')
local WindowSnapping = Enumeration('Disabled', 'TopLeft', 'TopRight')
local LayerFilter = Enumeration('AllLayers', 'ActiveLayers')

local userState = {}
local userStateSchema = {
    isModuleActive = { type = 'boolean', default = true },
    --isOnScreenDisplayActive = { type = 'boolean', default = false },
    selectedTab = { type = MainTab, default = MainTab.Inspect },
    layerFilter = { type = LayerFilter, default = LayerFilter.AllLayers },
    windowSnapping = { type = WindowSnapping, default = WindowSnapping.Disabled },
    inspectorTreeID = { type = 'number', default = 1 },
    inspectorTreeRows = { type = 'number', default = 12 },
    inspectorPropRows = { type = 'number', default = 9 },
    pickerResultListRows = { type = 'number', default = 10 },
    autoSnapOnScreenDisplay = { type = 'boolean', default = true },
    disablePickerOnConsoleOpen = { type = 'boolean', default = true },
    enforcePointerOnActivation = { type = 'boolean', default = true },
}

local function initializeUserState()
    PersistentState.Initialize(userState, modulePath .. '/.state', userStateSchema)
end

local function saveUserState()
    PersistentState.Flush(userState)
end

-- Highlighting --

local highlight = {
    target = nil,
    pending = nil,
    projections = {},
}

local function enableHighlight(target)
    if target and IsDefined(target.widget) then
        local area = inspectionSystem:GetWidgetDrawRect(target.widget)
        if area.width > 0 then
            highlight.target = target
            highlight.projections[target.hash] = {
                widget = target.widget,
                area = area,
                color = 0xFF32FF1D,
            }
        end
    end
end

local function disableHighlights()
    highlight.target = nil
    highlight.projections = {}
end

local function updateHighlights()
    disableHighlights()

    if highlight.pending then
        enableHighlight(highlight.pending)
        highlight.pending = nil
    end
end

local function highlightTarget(target)
    if target and target.hash then
        highlight.pending = target
    else
        highlight.pending = nil
    end
end

-- Inspector --

local inspector = {
    layers = nil,
    target = nil,
}

local function updateInspector(collect)
    if collect then
        inspector.layers = inspectionSystem:CollectInkLayers()

        for _, layer in ipairs(inspector.layers) do
            layer.scope = 'layer'
            for _, window in ipairs(layer.windows) do
                window.scope = 'window'
            end
        end
    end

    if inspector.target and inspector.target.widget and not IsDefined(inspector.target.widget) then
        inspector.target = nil
    end

    if inspector.target and IsDefined(inspector.target.widget) then
        highlightTarget(inspector.target)
    end
end

local function selectInspectedTarget(object, scope)
    if not inspector.layers then
        updateInspector(true)
    end

    local target = {}
    target.scope = scope

    if target.scope == 'layer' then
        target.layer = object
        inspector.target = target
        return
    end

    if target.scope == 'window' then
        target.window = object
        target.widget = object.handle
    else
        target.widget = object
    end

    target.hash = inspectionSystem:GetObjectHash(target.widget)
    target.spawnInfo = inspectionSystem:GetWidgetSpawnInfo(target.widget)

    if not target.window then
        local hashPath = {}
        local namePath = {}
        local indexPath = {}
        local widget = target.widget
        while not widget:IsA('inkWindow') do
            local parent = widget.parentWidget
            local hash = inspectionSystem:GetObjectHash(widget)
            local index = 0
            while index < parent:GetNumChildren() do
                if inspectionSystem:GetObjectHash(parent:GetWidgetByIndex(index)) == hash then
                    break
                end
                index = index + 1
            end
            table.insert(namePath, 1, widget.name.value)
            table.insert(indexPath, 1, parent:GetClassName().value .. '[' .. tostring(index) .. ']')
            hashPath[tonumber(hash)] = true
            widget = parent
        end

        target.namePathStr = table.concat(namePath, '/')
        target.indexPathStr = table.concat(indexPath, ' / ')

        local windowHash = inspectionSystem:GetObjectHash(widget)
        for _, layer in ipairs(inspector.layers) do
            if inspectionSystem:GetTypeName(layer.handle) == target.spawnInfo.layerName then
                hashPath[tonumber(layer.hash)] = true
                for _, window in ipairs(layer.windows) do
                    if window.hash == windowHash then
                        hashPath[tonumber(window.hash)] = true
                        target.window = window
                        break
                    end
                end
                break
            end
        end

        hashPath[tonumber(target.hash)] = nil
        target.hashPathMap = hashPath
    else
        local hashPath = {}
        for _, layer in ipairs(inspector.layers) do
            if inspectionSystem:GetTypeName(layer.handle) == target.spawnInfo.layerName then
                hashPath[tonumber(layer.hash)] = true
                break
            end
        end

        target.hashPathMap = hashPath
    end

    inspector.target = target
end

local function getChildIndex(target, hash)
    if not hash then
        hash = inspectionSystem:GetObjectHash(target)
    end
    local index = 0
    local parent = target.parentWidget
    while index < parent:GetNumChildren() do
        if inspectionSystem:GetObjectHash(parent:GetWidgetByIndex(index)) == hash then
            break
        end
        index = index + 1
    end
    return index
end

local function describeTarget(target, withName, withContent, maxTextLength)
    if not maxTextLength then
        maxTextLength = 32
    end

    local description = {}

    table.insert(description, inspectionSystem:GetTypeName(target).value)

    if inspectionSystem:IsInstanceOf(target, 'inkWidget') then
        if withName then
            local name = target:GetName().value
            if name ~= '' and name ~= 'None' and name ~= 'UNINITIALIZED_WIDGET' and name ~= 'Base Window' then
                table.insert(description, '#')
                table.insert(description, name)
            end
        end

        if withContent then
            local content
            if inspectionSystem:IsInstanceOf(target, 'inkTextWidget') then
                content = target:GetText()
                if content == '' then
                    content = GetLocalizedTextByKey(target:GetLocalizationKey())
                end
                if content:len() > maxTextLength then
                    content = content:sub(0, maxTextLength) .. '...'
                end
            elseif inspectionSystem:IsInstanceOf(target, 'inkImageWidget') then
                local textureAtlas = inspectionSystem:ResolveResourcePath(target.textureAtlas.hash)
                if textureAtlas ~= '' then
                    local textureAtlasName = textureAtlas:match('\\([^\\]+)$')
                    if not textureAtlasName then
                        textureAtlasName = textureAtlas
                    end
                    content = textureAtlasName .. ' : ' .. target.texturePart.value
                end
            end

            if content and content ~= '' then
                table.insert(description, '[' .. content .. ']')
            end
        end
    end

    return table.concat(description, ' ')
end

-- Picker --

local picker = {
    results = nil,
}

local function updatePicker(collect)
    if collect then
        local collection = inspectionSystem:CollectHoveredWidgets()

        picker.target = {
            layerName = collection.layerName.value,
            windowName = 'inkVirtualWindow',
            entity = collection.entity,
        }

        picker.results = collection.widgets

        table.sort(picker.results, function(a, b)
            if a.isInteractive ~= b.isInteractive then
                return a.isInteractive
            end
            return false
            --return a.depth > b.depth
        end)
    end

    if picker.results then
        for i = #picker.results, 1, -1 do
            if not IsDefined(picker.results[i].handle) then
                table.remove(picker.results, i)
            end
        end
    end

    updateInspector(false)
end

-- GUI --

local viewState = {
    isFirstOpen = true,
    isConsoleOpen = false,
    isWindowOpen = true,
    isWindowExpanded = true,
    isEditorFirstTabOpen = true,
    clipboard = nil,
}

local viewData = {
    maxInputLen = 512,
    widgetTypes = {
        'inkCanvasWidget',
        'inkFlexWidget',
        'inkHorizontalPanelWidget',
        'inkVerticalPanelWidget',
        'inkTextWidget',
        'inkRichTextBoxWidget',
        'inkImageWidget',
        'inkVideoWidget',
        'inkMaskWidget',
        'inkRectangleWidget',
        'inkCircleWidget',
        'inkBorderWidget',
        'inkGradientWidget',
        'inkLinePatternWidget',
        'inkShapeWidget',
        'inkQuadShapeWidget',
        'inkGridWidget',
        'inkUniformGridWidget',
        'inkScrollAreaWidget',
        'inkCacheWidget',
    },
}

local viewStyle = {
    labelTextColor = 0xFFA5A19B,
    mutedTextColor = 0xFFA5A19B,
    hintTextColor = 0x66FFFFFF,
    dangerTextColor = 0xFF6666FF,
    disabledButtonColor = 0xFF4F4F4F,
    groupCaptionColor = 0xFFA5A19B,
    groupCaptionSize = 0.75,
    contextCaptionColor = 0xFFA5A19B,
    contextCaptionSize = 0.85,
    showEditorCaptions = false,
    showEditorNestedGroups = true,
}

local function initializeViewData()
    viewData.windowSnappingOptions = ImGuiEx.BuildComboOptions(WindowSnapping.values, true)
    viewData.layerFilterOptions = ImGuiEx.BuildComboOptions(LayerFilter.values, true)

	viewData.inkEAnchor = ImGuiEx.BuildEnumOptions('inkEAnchor')
	viewData.inkESizeRule = ImGuiEx.BuildEnumOptions('inkESizeRule')
	viewData.inkEHorizontalAlign = ImGuiEx.BuildEnumOptions('inkEHorizontalAlign')
	viewData.inkEVerticalAlign = ImGuiEx.BuildEnumOptions('inkEVerticalAlign')
	viewData.inkEChildOrder = ImGuiEx.BuildEnumOptions('inkEChildOrder')
	viewData.inkBrushMirrorType = ImGuiEx.BuildEnumOptions('inkBrushMirrorType')
	viewData.inkBrushTileType = ImGuiEx.BuildEnumOptions('inkBrushTileType')
	viewData.inkMaskDataSource = ImGuiEx.BuildEnumOptions('inkMaskDataSource')
	viewData.inkEOrientation = ImGuiEx.BuildEnumOptions('inkEOrientation')
	viewData.inkFitToContentDirection = ImGuiEx.BuildEnumOptions('inkFitToContentDirection')
	viewData.inkEShapeVariant = ImGuiEx.BuildEnumOptions('inkEShapeVariant')
	viewData.inkEEndCapStyle = ImGuiEx.BuildEnumOptions('inkEEndCapStyle')
	viewData.inkEJointStyle = ImGuiEx.BuildEnumOptions('inkEJointStyle')
	viewData.inkGradientMode = ImGuiEx.BuildEnumOptions('inkGradientMode')
	viewData.inkCacheMode = ImGuiEx.BuildEnumOptions('inkCacheMode')
    viewData.textLetterCase = ImGuiEx.BuildEnumOptions('textLetterCase')
	viewData.textJustificationType = ImGuiEx.BuildEnumOptions('textJustificationType')
	viewData.textHorizontalAlignment = ImGuiEx.BuildEnumOptions('textHorizontalAlignment')
	viewData.textVerticalAlignment = ImGuiEx.BuildEnumOptions('textVerticalAlignment')
	viewData.textOverflowPolicy = ImGuiEx.BuildEnumOptions('textOverflowPolicy')
	viewData.textWrappingPolicy = ImGuiEx.BuildEnumOptions('textWrappingPolicy')
end

local function initializeViewStyle()
    if not viewStyle.fontSize then
        viewStyle.fontSize = ImGui.GetFontSize()
        viewStyle.viewScale = viewStyle.fontSize / 13

        local screenX, screenY = GetDisplayResolution()

        viewStyle.windowPaddingX = 8 * viewStyle.viewScale
        viewStyle.windowPaddingY = viewStyle.windowPaddingX
        viewStyle.windowWidth = 400 * viewStyle.viewScale
        viewStyle.windowFullWidth = viewStyle.windowWidth + viewStyle.windowPaddingX * 2 - 1
        viewStyle.windowFrameWidth = viewStyle.windowFullWidth - ImGui.GetStyle().ScrollbarSize
        viewStyle.windowHeight = 0
        viewStyle.windowTopY = 4
        viewStyle.windowLeftX = 4
        viewStyle.windowRightX = screenX - viewStyle.windowFullWidth - 4
        viewStyle.windowDefaultX = (screenX - viewStyle.windowFullWidth - 4) / 2
        viewStyle.windowDefaultY = (screenY - 100) / 2

        viewStyle.mainWindowFlags = ImGuiWindowFlags.NoResize
            + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse
        viewStyle.pickerWindowFlags = ImGuiWindowFlags.NoResize
            + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse
            + ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoCollapse
            + ImGuiWindowFlags.NoInputs + ImGuiWindowFlags.NoNav
        viewStyle.projectionWindowFlags = ImGuiWindowFlags.NoSavedSettings
            + ImGuiWindowFlags.NoInputs + ImGuiWindowFlags.NoNav
            + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove
            + ImGuiWindowFlags.NoDecoration + ImGuiWindowFlags.NoBackground
            + ImGuiWindowFlags.NoFocusOnAppearing + ImGuiWindowFlags.NoBringToFrontOnFocus

        viewStyle.inspectorFilterWidth = 85 * viewStyle.viewScale

        viewStyle.editorLabelSmallWidth = 70 * viewStyle.viewScale
        viewStyle.editorLabelMiddleWidth = 110 * viewStyle.viewScale
        viewStyle.editorLabelLargeWidth = 130 * viewStyle.viewScale
        viewStyle.editorLabelWidth = viewStyle.editorLabelLargeWidth
        viewStyle.editorLabelIndent = 0

        viewStyle.editorInputPaddingX = 6
        viewStyle.editorInputPaddingY = ImGui.GetStyle().FramePadding.y
        viewStyle.editorInputFullWidth = -1
        viewStyle.editorInputHalfWidth = -2
        viewStyle.editorInputFourthWidth = -4
        viewStyle.editorInputHeight = ImGui.GetFrameHeightWithSpacing()

        viewStyle.settingsMiddleComboRowWidth = 210 * viewStyle.viewScale
    end
end

-- GUI :: Editor --

local function drawEditorGroupCaption(caption, labelWidth)
    --local x, y = ImGui.GetCursorScreenPos()
    --local w = viewStyle.windowFullWidth
    --local h = ImGui.GetTextLineHeight()
    --ImGui.ImDrawListAddRectFilled(ImGui.GetWindowDrawList(), x, y, x + w, y + h - 1, ImGui.GetColorU32(ImGuiCol.MenuBarBg, 1))

    if viewStyle.showEditorCaptions then
        ImGui.Spacing()
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
        ImGui.SetWindowFontScale(viewStyle.groupCaptionSize)
        ImGui.Text(caption)
        ImGui.SetWindowFontScale(1.0)
        ImGui.PopStyleColor()
    end

    viewStyle.editorLabelWidth = labelWidth or viewStyle.editorLabelLargeWidth
end

local function drawEditorLabel(label)
    if viewStyle.editorLabelIndent > 0 then
        label = string.rep('  ', viewStyle.editorLabelIndent - 1) .. '·  ' .. label
    end
    ImGui.AlignTextToFramePadding()
    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
    ImGui.Text(label)
    ImGui.PopStyleColor()
    ImGui.SameLine()
    if ImGui.GetCursorPosX() < viewStyle.editorLabelWidth then
        ImGui.SameLine(viewStyle.editorLabelWidth)
    end
end

local function pushEditorNestedGroup(label, force)
    if viewStyle.showEditorNestedGroups or force then
        ImGui.BeginGroup()
        drawEditorLabel(label)
        ImGui.EndGroup()
        viewStyle.editorLabelIndent = viewStyle.editorLabelIndent + 1
    end
end

local function popEditorNestedGroup(force)
    if viewStyle.showEditorNestedGroups or force then
        viewStyle.editorLabelIndent = viewStyle.editorLabelIndent - 1
    end
end

local function ensureEditorInputWidth(rowWidth)
    if rowWidth == viewStyle.editorInputFullWidth then
        ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail())
    elseif rowWidth == viewStyle.editorInputHalfWidth then
        ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail() / 2)
    elseif rowWidth == viewStyle.editorInputFourthWidth then
        ImGui.SetNextItemWidth(ImGui.GetContentRegionAvail() / 4)
    elseif rowWidth and rowWidth > 0 then
        ImGui.SetNextItemWidth(rowWidth)
    end
end

local function drawEditorTextInput(label, value, rowWidth)
    ImGui.BeginGroup()
    drawEditorLabel(label)
    ensureEditorInputWidth(rowWidth)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, viewStyle.editorInputPaddingX, viewStyle.editorInputPaddingY)
    local input, changed = ImGui.InputText('##' .. label, value, 32768)
    ImGui.PopStyleVar()
    ImGui.EndGroup()
    return input, changed
end

local function drawEditorEnumInput(label, value, options, rowWidth)
    ImGui.BeginGroup()
    drawEditorLabel(label)
    ensureEditorInputWidth(rowWidth)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, viewStyle.editorInputPaddingX, viewStyle.editorInputPaddingY)
    local input, changed = ImGui.Combo('##' .. label, tonumber(EnumInt(value)), options, #options)
    ImGui.PopStyleVar()
    ImGui.EndGroup()
    return input, changed
end

local function drawEditorIntegerInput(label, value, baseStep, fastStep, rowWidth)
    ImGui.BeginGroup()
    drawEditorLabel(label)
    ensureEditorInputWidth(rowWidth)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, viewStyle.editorInputPaddingX, viewStyle.editorInputPaddingY)
    local input, changed = ImGui.InputInt('##' .. label, value, baseStep, fastStep, ImGuiInputTextFlags.None)
    ImGui.PopStyleVar()
    ImGui.EndGroup()
    return input, changed
end

local function drawEditorFloatInput(label, value, format, baseStep, fastStep, rowWidth)
    ImGui.BeginGroup()
    drawEditorLabel(label)
    ensureEditorInputWidth(rowWidth)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, viewStyle.editorInputPaddingX, viewStyle.editorInputPaddingY)
    local input, changed = ImGui.InputFloat('##' .. label, value, baseStep, fastStep, format, ImGuiInputTextFlags.None)
    ImGui.PopStyleVar()
    ImGui.EndGroup()
    return input, changed
end

local function drawEditorVector2Input(label, value, format, rowWidth)
    ImGui.BeginGroup()
    drawEditorLabel(label)
    ensureEditorInputWidth(rowWidth)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, viewStyle.editorInputPaddingX, viewStyle.editorInputPaddingY)
    local input, changed = ImGui.InputFloat2('##' .. label, { value.X, value.Y }, format, ImGuiInputTextFlags.None)
    ImGui.PopStyleVar()
    ImGui.EndGroup()
    if changed then
        input = Vector2.new({ X = input[1], Y = input[2] })
    end
    return input, changed
end

local function drawEditorMarginInput(label, value, format, rowWidth)
    ImGui.BeginGroup()
    drawEditorLabel(label)
    ensureEditorInputWidth(rowWidth)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, viewStyle.editorInputPaddingX, viewStyle.editorInputPaddingY)
    local input, changed = ImGui.InputFloat4('##' .. label, { value.left, value.top, value.right, value.bottom }, format, ImGuiInputTextFlags.None)
    ImGui.PopStyleVar()
    ImGui.EndGroup()
    if changed then
        input = inkMargin.new({ left = input[1], top = input[2], right = input[3], bottom = input[4] })
    end
    return input, changed
end

local function drawEditorHDRColorInput(label, value, rowWidth)
    ImGui.BeginGroup()
    drawEditorLabel(label)
    ensureEditorInputWidth(rowWidth)
    local input, changed = ImGui.ColorEdit4('##' .. label, { value.Red, value.Green, value.Blue, value.Alpha },
        ImGuiColorEditFlags.NoTooltip + ImGuiColorEditFlags.Float + ImGuiColorEditFlags.HDR)
    ImGui.EndGroup()
    if changed then
        input = HDRColor.new({ Red = input[1], Green = input[2], Blue = input[3], Alpha = input[4] })
    end
    return input, changed
end

local function drawEditorCheckbox(label, value)
    ImGui.BeginGroup()
    drawEditorLabel(label)
    local input, changed = ImGui.Checkbox('##' .. label, value)
    ImGui.EndGroup()
    return input, changed
end

local function drawEditorStaticData(label, data)
    ImGui.BeginGroup()
    drawEditorLabel(label)
    ImGui.BeginGroup()
    if type(data) == 'table' then
        if #data > 0 then
            for _, item in ipairs(data) do
                ImGui.TextWrapped(tostring(item))
                if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
                    ImGui.SetClipboardText(tostring(item))
                end
            end
        else
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
            ImGui.Text('(empty)')
            ImGui.PopStyleColor()
        end
    else
        if data ~= nil then
            ImGui.TextWrapped(tostring(data))
            if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
                ImGui.SetClipboardText(tostring(data))
            end
        else
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
            ImGui.Text('(null)')
            ImGui.PopStyleColor()
        end
    end
    ImGui.EndGroup()
    ImGui.EndGroup()
end

local function drawGeneralFieldset(target)
    drawEditorGroupCaption('GENERAL')

    local input, changed = drawEditorTextInput('name', target.name.value, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetName(StringToName(input))
    end

    input, changed = drawEditorCheckbox('visible', target.visible)
    if changed then
        target:SetVisible(input)
    end
end

local function drawAppearanceFieldset(target, mergeGroup)
    if not mergeGroup then
        drawEditorGroupCaption('APPEARANCE')
    end

    local input, changed = drawEditorHDRColorInput('tintColor', target.tintColor, viewStyle.editorInputFullWidth)
    if changed then
        target:SetTintColor(input)
    end

    input, changed = drawEditorFloatInput('opacity', target.opacity, '%.3f', 0.001, 0.1, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetOpacity(input)
    end
end

local function drawLayoutFieldset(target)
    drawEditorGroupCaption('LAYOUT')

    pushEditorNestedGroup('layout')

    local layout = target.layout

    local input, changed = drawEditorEnumInput('anchor', layout.anchor, viewData.inkEAnchor, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetAnchor(input)
    end

    input, changed = drawEditorVector2Input('anchorPoint', layout.anchorPoint, '%.2f', viewStyle.editorInputHalfWidth)
    if changed then
        target:SetAnchorPoint(input)
    end

    input, changed = drawEditorEnumInput('HAlign', layout.HAlign, viewData.inkEHorizontalAlign, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetHAlign(input)
    end

    input, changed = drawEditorEnumInput('VAlign', layout.VAlign, viewData.inkEVerticalAlign, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetVAlign(input)
    end

    input, changed = drawEditorMarginInput('margin', layout.margin, '%.2f', viewStyle.editorInputFullWidth)
    if changed then
        target:SetMargin(input)
    end

    input, changed = drawEditorMarginInput('padding', layout.padding, '%.2f', viewStyle.editorInputFullWidth)
    if changed then
        target:SetPadding(input)
    end

    input, changed = drawEditorEnumInput('sizeRule', layout.sizeRule, viewData.inkESizeRule, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetSizeRule(input)
    end

    input, changed = drawEditorFloatInput('sizeCoefficient', layout.sizeCoefficient, '%.f', 0.001, 0.1, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetSizeCoefficient(input)
    end

	popEditorNestedGroup()

    input, changed = drawEditorVector2Input('size', target.size, '%.2f', viewStyle.editorInputHalfWidth)
    if changed then
        target:SetSize(input)
    end

    input, changed = drawEditorCheckbox('fitToContent', target.fitToContent)
    if changed then
        target:SetFitToContent(input)
    end

    input, changed = drawEditorCheckbox('affectsLayoutWhenHidden', target.affectsLayoutWhenHidden)
    if changed then
        target:SetAffectsLayoutWhenHidden(input)
    end
end

local function drawTransformFieldset(target)
    drawEditorGroupCaption('TRANSFORM')

    pushEditorNestedGroup('renderTransform', true)

    local transform = target.renderTransform

    local input, changed = drawEditorVector2Input('translation', transform.translation, '%.2f', viewStyle.editorInputHalfWidth)
    if changed then
        target:SetTranslation(input)
    end

    input, changed = drawEditorVector2Input('scale', transform.scale, '%.2f', viewStyle.editorInputHalfWidth)
    if changed then
        target:SetScale(input)
    end

    input, changed = drawEditorVector2Input('shear', transform.shear, '%.2f', viewStyle.editorInputHalfWidth)
    if changed then
        target:SetShear(input)
    end

    input, changed = drawEditorFloatInput('rotation', transform.rotation, '%.2f', 0, 0, viewStyle.editorInputFourthWidth, false)
    if changed then
        target:SetRotation(input)
    end

	popEditorNestedGroup(true)

    input, changed = drawEditorVector2Input('renderTransformPivot', target.renderTransformPivot, '%.2f', viewStyle.editorInputHalfWidth)
    if changed then
        target:SetRenderTransformPivot(input)
    end
end

local function drawEffectsFieldset(target)
    drawEditorGroupCaption('EFFECTS')

    local effectNames = {}
    for _, effect in ipairs(target.effects) do
        table.insert(effectNames, inspectionSystem:GetTypeName(effect).value)
    end

    drawEditorStaticData('effects', effectNames)
end

local function drawStyleFieldset(target)
    drawEditorGroupCaption('BINDINGS')

    local styleWrapper = target.style
    local styleResource = IsDefined(styleWrapper) and inspectionSystem:ResolveResourcePath(target.style.styleResource.hash) or ''
    local input, changed = drawEditorTextInput('style', styleResource, viewStyle.editorInputFullWidth)
    if changed then
        target:SetStyle(ResRef.FromString(input))
    end

    input, changed = drawEditorTextInput('state', target.state.value, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetState(StringToName(input))
    end

    local propertyManager = target.propertyManager
    local propertyName, stylePath, confirmed

    ImGui.BeginGroup()
    drawEditorLabel('propertyManager')
    ensureEditorInputWidth(viewStyle.editorInputFullWidth)
    ImGui.BeginGroup()
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, viewStyle.editorInputPaddingX, viewStyle.editorInputPaddingY)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 2 * viewStyle.viewScale, 4 * viewStyle.viewScale)

    if IsDefined(propertyManager) then
        for i, binding in ipairs(propertyManager.bindings) do
            ImGui.PushID(i)

            ImGui.SetNextItemWidth(80 * viewStyle.viewScale)
            propertyName, confirmed = ImGui.InputText('##Property', binding.propertyName.value, 256, ImGuiInputTextFlags.EnterReturnsTrue)
            if confirmed and propertyName ~= binding.propertyName.value then
                if target:BindProperty(propertyName, binding.stylePath) then
                    target:UnbindProperty(binding.propertyName)
                end
            end

            ImGui.SameLine()
            ImGui.SetNextItemWidth(160 * viewStyle.viewScale)
            stylePath, confirmed = ImGui.InputText('##Value', binding.stylePath.value, 256, ImGuiInputTextFlags.EnterReturnsTrue)
            if confirmed and stylePath ~= binding.stylePath.value then
                target:BindProperty(binding.propertyName, stylePath)
            end

            ImGui.SameLine()
            if ImGui.Button(' X ') then
                target:UnbindProperty(binding.propertyName)
            end

            ImGui.PopID()
        end
    end

    ImGui.SetNextItemWidth(242 * viewStyle.viewScale)
    propertyName, confirmed = ImGui.InputTextWithHint('##Property', 'Add property...', '', 256, ImGuiInputTextFlags.EnterReturnsTrue)
    if confirmed then
        target:BindProperty(propertyName, 'None')
    end

    ImGui.PopStyleVar(2)
    ImGui.EndGroup()
    ImGui.EndGroup()
end

local function drawInteractionFieldset(target)
    drawEditorGroupCaption('INTERACTION')

    local input, changed = drawEditorCheckbox('isInteractive', target.isInteractive)
    if changed then
        target:SetInteractive(input)
    end

    input, changed = drawEditorCheckbox('canSupportFocus', target.canSupportFocus)
    if changed then
        target.canSupportFocus = input
    end
end

local function drawLogicFieldset(target)
    drawEditorGroupCaption('LOGIC')

    local logicController = target.logicController
    local logicControllerName = IsDefined(logicController) and logicController:GetClassName().value or nil

    local secondaryControllerNames = {}
    for _, secondaryController in ipairs(target.secondaryControllers) do
        table.insert(secondaryControllerNames, secondaryController:GetClassName().value)
    end

    local userDataNames = {}
    for _, userData in ipairs(target.userData) do
        table.insert(userDataNames, userData:GetClassName().value)
    end

    drawEditorStaticData('logicController', logicControllerName)
    drawEditorStaticData('secondaryControllers', secondaryControllerNames)
    drawEditorStaticData('userData', userDataNames)
end

local function drawContainerFieldset(target)
    drawEditorGroupCaption('CONTAINER')

    local input, changed = drawEditorEnumInput('childOrder', target.childOrder, viewData.inkEChildOrder, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetChildOrder(input)
    end

    input, changed = drawEditorMarginInput('childMargin', target.childMargin, '%.2f', viewStyle.editorInputFullWidth)
    if changed then
        target:SetChildMargin(input)
    end
end

local function drawTextContentFieldset(target)
    drawEditorGroupCaption('TEXT')

    local input, changed = drawEditorTextInput('text', target.text, viewStyle.editorInputFullWidth)
    if changed then
        target:SetLocalizationKey(CName.new())
        target:SetTextDirect(input)
    end

	-- TODO: localizationString : LocalizationString

    input, changed = drawEditorIntegerInput('textIdKey', target.textIdKey.hash_lo, 1, 1, viewStyle.editorInputHalfWidth)
    if changed then
        local key = ToCName{ hash_lo = input }
        local text = GetLocalizedTextByKey(key)
        if text ~= '' then
            target:SetTextDirect(text)
            target:SetLocalizationKey(key)
        end
    end
end

local function drawTextSettingsFieldset(target)
    drawEditorGroupCaption('FONT')

    local fontFamily = inspectionSystem:ResolveResourcePath(target.fontFamily.hash)
    local input, changed = drawEditorTextInput('fontFamily', fontFamily, viewStyle.editorInputFullWidth)
    if changed then
        target:SetFontFamily(input)
    end

    input, changed = drawEditorTextInput('fontStyle', target.fontStyle.value, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetFontStyle(input)
    end

    input, changed = drawEditorIntegerInput('fontSize', target.fontSize, 1, 10, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetFontSize(input)
    end

    input, changed = drawEditorIntegerInput('tracking', target.tracking, 1, 10, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetTracking(input)
    end

    input, changed = drawEditorFloatInput('lineHeightPercentage', target.lineHeightPercentage, '%.3f', 0.001, 0.1, viewStyle.editorInputHalfWidth)
    if changed then
        target.lineHeightPercentage = input
    end

    input, changed = drawEditorEnumInput('letterCase', target.letterCase, viewData.textLetterCase, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetLetterCase(input)
    end

    input, changed = drawEditorCheckbox('lockFontInGame', target.lockFontInGame)
    if changed then
        target.lockFontInGame = input
    end

    drawEditorGroupCaption('TEXT ALIGNMENT', viewStyle.editorLabelLargeWidth)

    input, changed = drawEditorEnumInput('justification', target.justification, viewData.textJustificationType, viewStyle.editorInputHalfWidth)
    if changed then
        target.justification = input
    end

    input, changed = drawEditorEnumInput('textHorizontalAlignment', target.textHorizontalAlignment, viewData.textHorizontalAlignment, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetHorizontalAlignment(input)
    end

    input, changed = drawEditorEnumInput('textVerticalAlignment', target.textVerticalAlignment, viewData.textVerticalAlignment, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetVerticalAlignment(input)
    end

    input, changed = drawEditorEnumInput('contentHAlign', target.contentHAlign, viewData.inkEHorizontalAlign, viewStyle.editorInputHalfWidth)
    if changed then
        target.contentHAlign = input
    end

    input, changed = drawEditorEnumInput('contentVAlign', target.contentVAlign, viewData.inkEVerticalAlign, viewStyle.editorInputHalfWidth)
    if changed then
        target.contentVAlign = input
    end

    drawEditorGroupCaption('TEXT OVERFLOW', viewStyle.editorLabelLargeWidth)

    input, changed = drawEditorEnumInput('textOverflowPolicy', target.textOverflowPolicy, viewData.textOverflowPolicy, viewStyle.editorInputHalfWidth)
    if changed then
        target.textOverflowPolicy = input
    end

    pushEditorNestedGroup('wrappingInfo')

    local wrappingInfo = target.wrappingInfo

    input, changed = drawEditorCheckbox('autoWrappingEnabled', wrappingInfo.autoWrappingEnabled)
    if changed then
        wrappingInfo.autoWrappingEnabled = input
        target.wrappingInfo = wrappingInfo
    end

    input, changed = drawEditorFloatInput('wrappingAtPosition', wrappingInfo.wrappingAtPosition, '%.f', 1.0, 10.0, viewStyle.editorInputHalfWidth)
    if changed then
        wrappingInfo.wrappingAtPosition = input
        target.wrappingInfo = wrappingInfo
    end

    input, changed = drawEditorEnumInput('wrappingPolicy', wrappingInfo.wrappingPolicy, viewData.textWrappingPolicy, viewStyle.editorInputHalfWidth)
    if changed then
        wrappingInfo.wrappingPolicy = input
        target.wrappingInfo = wrappingInfo
    end

    popEditorNestedGroup()

    drawEditorGroupCaption('TEXT SCROLLING')

    input, changed = drawEditorFloatInput('scrollTextSpeed', target.scrollTextSpeed, '%.f', 1.0, 10.0, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetScrollTextSpeed(input)
    end

    input, changed = drawEditorIntegerInput('scrollDelay', target.scrollDelay, 1, 10, viewStyle.editorInputHalfWidth)
    if changed then
        target.scrollDelay = input
    end
end

local function drawImageContentFieldset(target)
    drawEditorGroupCaption('IMAGE')

    local textureAtlas = inspectionSystem:ResolveResourcePath(target.textureAtlas.hash)
    local input, changed = drawEditorTextInput('textureAtlas', textureAtlas, viewStyle.editorInputFullWidth)
    if changed then
        target:SetAtlasResource(ResRef.FromString(input))
    end

    input, changed = drawEditorTextInput('texturePart', target.texturePart.value, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetTexturePart(input)
    end

    input, changed = drawEditorCheckbox('useExternalDynamicTexture', target.useExternalDynamicTexture)
    if changed then
        target.useExternalDynamicTexture = input
    end

    input, changed = drawEditorTextInput('externalDynamicTexture', target.externalDynamicTexture.value, viewStyle.editorInputHalfWidth)
    if changed then
        target.externalDynamicTexture = input
    end
end

local function drawImageSettingsFieldset(target)
    drawEditorGroupCaption('IMAGE ALIGNMENT')

    local input, changed = drawEditorEnumInput('contentHAlign', target.contentHAlign, viewData.inkEHorizontalAlign, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetContentHAlign(input)
    end

    input, changed = drawEditorEnumInput('contentVAlign', target.contentVAlign, viewData.inkEVerticalAlign, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetContentVAlign(input)
    end

    input, changed = drawEditorEnumInput('mirrorType', target.mirrorType, viewData.inkBrushMirrorType, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetBrushMirrorType(input)
    end

    drawEditorGroupCaption('IMAGE SCALING')

    input, changed = drawEditorCheckbox('useNineSliceScale', target.useNineSliceScale)
    if changed then
        target.useNineSliceScale = input
    end

    input, changed = drawEditorMarginInput('nineSliceScale', target.nineSliceScale, '%.2f', viewStyle.editorInputFullWidth)
    if changed then
        target.nineSliceScale = input
    end

    drawEditorGroupCaption('IMAGE TILING')

    input, changed = drawEditorEnumInput('tileType', target.tileType, viewData.inkBrushTileType, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetBrushTileType(input)
    end

    input, changed = drawEditorEnumInput('tileHAlign', target.tileHAlign, viewData.inkEHorizontalAlign, viewStyle.editorInputHalfWidth)
    if changed then
        target.tileHAlign = input
    end

    input, changed = drawEditorEnumInput('tileVAlign', target.tileVAlign, viewData.inkEVerticalAlign, viewStyle.editorInputHalfWidth)
    if changed then
        target.tileVAlign = input
    end

    input, changed = drawEditorFloatInput('horizontalTileCrop', target.horizontalTileCrop, '%.f', 1.0, 10.0, viewStyle.editorInputHalfWidth)
    if changed then
        target.horizontalTileCrop = input
    end

    input, changed = drawEditorFloatInput('verticalTileCrop', target.verticalTileCrop, '%.f', 1.0, 10.0, viewStyle.editorInputHalfWidth)
    if changed then
        target.verticalTileCrop = input
    end
end

local function drawVideoFieldset(target)
    drawEditorGroupCaption('VIDEO')

    local videoResource = inspectionSystem:ResolveResourcePath(target.videoResource.hash)
    local input, changed = drawEditorTextInput('videoResource', videoResource, viewStyle.editorInputFullWidth)
    if changed then
        target:SetVideoPath(ResRef.FromString(input))
    end

    input, changed = drawEditorTextInput('overriddenPlayerName', target.overriddenPlayerName.value, viewStyle.editorInputHalfWidth)
    if changed then
        target.overriddenPlayerName = input
    end

    input, changed = drawEditorCheckbox('isParallaxEnabled', target.isParallaxEnabled)
    if changed then
        target.isParallaxEnabled = input
    end

    input, changed = drawEditorCheckbox('prefetchVideo', target.prefetchVideo)
    if changed then
        target.prefetchVideo = input
    end

    input, changed = drawEditorCheckbox('loop', target.loop)
    if changed then
        target.loop = input
    end
end

local function drawShapeFieldset(target)
	drawEditorGroupCaption('SHAPE')

    local shapeResource = inspectionSystem:ResolveResourcePath(target.shapeResource.hash)
    local input, changed = drawEditorTextInput('shapeResource', shapeResource, viewStyle.editorInputFullWidth)
    if changed then
        target.shapeResource = input
    end

    input, changed = drawEditorTextInput('shapeName', target.shapeName.value, viewStyle.editorInputHalfWidth)
    if changed then
        target:ChangeShape(input)
    end

    drawEditorGroupCaption('SHAPE SCALING')

    input, changed = drawEditorCheckbox('useNineSlice', target.useNineSlice)
    if changed then
        target.useNineSlice = input
    end

    input, changed = drawEditorMarginInput('nineSliceScale', target.nineSliceScale, '%.2f', viewStyle.editorInputFullWidth)
    if changed then
        target.nineSliceScale = input
    end

    drawEditorGroupCaption('SHAPE ALIGNMENT')

    input, changed = drawEditorEnumInput('contentHAlign', target.contentHAlign, viewData.inkEHorizontalAlign, viewStyle.editorInputHalfWidth)
    if changed then
        target.contentHAlign = input
    end

    input, changed = drawEditorEnumInput('contentVAlign', target.contentVAlign, viewData.inkEVerticalAlign, viewStyle.editorInputHalfWidth)
    if changed then
        target.contentVAlign = input
    end

    input, changed = drawEditorCheckbox('keepInBounds', target.keepInBounds)
    if changed then
        target.keepInBounds = input
    end

    drawEditorGroupCaption('APPEARANCE')

    input, changed = drawEditorEnumInput('shapeVariant', target.shapeVariant, viewData.inkEShapeVariant, viewStyle.editorInputHalfWidth)
    if changed then
        target.shapeVariant = input
    end

    input, changed = drawEditorFloatInput('lineThickness', target.lineThickness, '%.f', 0.1, 1.0, viewStyle.editorInputHalfWidth)
    if changed then
        target.lineThickness = input
    end

    input, changed = drawEditorEnumInput('endCapStyle', target.endCapStyle, viewData.inkEEndCapStyle, viewStyle.editorInputHalfWidth)
    if changed then
        target.endCapStyle = input
    end

    input, changed = drawEditorEnumInput('jointStyle', target.jointStyle, viewData.inkEJointStyle, viewStyle.editorInputHalfWidth)
    if changed then
        target.jointStyle = input
    end

    input, changed = drawEditorFloatInput('borderOpacity', target.borderOpacity, '%.3f', 0.001, 0.1, viewStyle.editorInputHalfWidth)
    if changed then
        target.borderOpacity = input
    end

    input, changed = drawEditorHDRColorInput('borderColor', target.borderColor, viewStyle.editorInputFullWidth)
    if changed then
        target.borderColor = input
    end

    input, changed = drawEditorFloatInput('fillOpacity', target.fillOpacity, '%.3f', 0.001, 0.1, viewStyle.editorInputHalfWidth)
    if changed then
        target.fillOpacity = input
    end
end

local function drawQuadShapeFieldset(target)
	drawEditorGroupCaption('SHAPE')

    local textureAtlas = inspectionSystem:ResolveResourcePath(target.textureAtlas.hash)
    local input, changed = drawEditorTextInput('textureAtlas', textureAtlas, viewStyle.editorInputFullWidth)
    if changed then
        target.textureAtlas = input
    end

    input, changed = drawEditorTextInput('texturePart', target.texturePart.value, viewStyle.editorInputHalfWidth)
    if changed then
        target.texturePart = input
    end
end

local function drawCircleFieldset(target)
	drawEditorGroupCaption('APPEARANCE')

    local input, changed = drawEditorIntegerInput('segmentsNumber', target.segmentsNumber, 1, 1, viewStyle.editorInputHalfWidth)
    if changed then
        target.segmentsNumber = input
    end
end

local function drawBorderFieldset(target)
	drawEditorGroupCaption('APPEARANCE')

    local input, changed = drawEditorFloatInput('thickness', target.thickness, '%.f', 0.1, 1.0, viewStyle.editorInputHalfWidth)
    if changed then
        target.thickness = input
    end
end

local function drawGradientFieldset(target)
	drawEditorGroupCaption('GRADIENT')

    local input, changed = drawEditorEnumInput('gradientMode', target.gradientMode, viewData.inkGradientMode, viewStyle.editorInputHalfWidth)
    if changed then
        target.gradientMode = input
    end

    input, changed = drawEditorHDRColorInput('startColor', target.startColor, viewStyle.editorInputFullWidth)
    if changed then
        target.startColor = input
    end

    input, changed = drawEditorHDRColorInput('endColor', target.endColor, viewStyle.editorInputFullWidth)
    if changed then
        target.endColor = input
    end

    input, changed = drawEditorFloatInput('angle', target.angle, '%.f', 0.1, 1.0, viewStyle.editorInputHalfWidth)
    if changed then
        target.angle = input
    end
end

local function drawLinePatternFieldset(target)
	drawEditorGroupCaption('LINE PATTERN')

    local input, changed = drawEditorEnumInput('patternDirection', target.patternDirection, viewData.inkEChildOrder, viewStyle.editorInputHalfWidth)
    if changed then
        target.patternDirection = input
    end

    input, changed = drawEditorFloatInput('spacing', target.spacing, '%.f', 0.1, 1.0, viewStyle.editorInputHalfWidth)
    if changed then
        target.spacing = input
    end

    input, changed = drawEditorFloatInput('looseSpacing', target.looseSpacing, '%.f', 0.1, 1.0, viewStyle.editorInputHalfWidth)
    if changed then
        target.looseSpacing = input
    end

    input, changed = drawEditorFloatInput('startOffset', target.startOffset, '%.f', 0.1, 1.0, viewStyle.editorInputHalfWidth)
    if changed then
        target.startOffset = input
    end

    input, changed = drawEditorFloatInput('endOffset', target.endOffset, '%.f', 0.1, 1.0, viewStyle.editorInputHalfWidth)
    if changed then
        target.endOffset = input
    end

    input, changed = drawEditorFloatInput('fadeInLength', target.fadeInLength, '%.f', 0.1, 1.0, viewStyle.editorInputHalfWidth)
    if changed then
        target.fadeInLength = input
    end

    input, changed = drawEditorCheckbox('rotateWithSegment', target.rotateWithSegment)
    if changed then
        target.rotateWithSegment = input
    end
end

local function drawMaskFieldset(target)
    drawEditorGroupCaption('MASK')

    local input, changed = drawEditorEnumInput('dataSource', target.dataSource, viewData.inkMaskDataSource, viewStyle.editorInputHalfWidth)
    if changed then
        target.dataSource = input
    end

    local textureAtlas = inspectionSystem:ResolveResourcePath(target.textureAtlas.hash)
    input, changed = drawEditorTextInput('textureAtlas', textureAtlas, viewStyle.editorInputFullWidth)
    if changed then
        target.textureAtlas = input
    end

    input, changed = drawEditorTextInput('texturePart', target.texturePart.value, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetTexturePart(input)
    end

    input, changed = drawEditorTextInput('dynamicTextureMask', target.dynamicTextureMask.value, viewStyle.editorInputHalfWidth)
    if changed then
        target.dynamicTextureMask = input
    end

    input, changed = drawEditorFloatInput('maskTransparency', target.maskTransparency, '%.3f', 0.001, 0.1, viewStyle.editorInputHalfWidth)
    if changed then
        target.maskTransparency = input
    end

    input, changed = drawEditorCheckbox('invertMask', target.invertMask)
    if changed then
        target.invertMask = input
    end
end

local function drawScrollAreaFieldset(target)
    drawEditorGroupCaption('SCROLL AREA')

    local input, changed = drawEditorFloatInput('horizontalScrolling', target.horizontalScrolling, '%.3f', 0.001, 0.1, viewStyle.editorInputHalfWidth)
    if changed then
        target.horizontalScrolling = input
    end

    input, changed = drawEditorFloatInput('verticalScrolling', target.verticalScrolling, '%.3f', 0.001, 0.1, viewStyle.editorInputHalfWidth)
    if changed then
        target.verticalScrolling = input
    end

    input, changed = drawEditorEnumInput('fitToContentDirection', target.fitToContentDirection, viewData.inkFitToContentDirection, viewStyle.editorInputHalfWidth)
    if changed then
        target.fitToContentDirection = input
    end

    input, changed = drawEditorCheckbox('constrainContentPosition', target.constrainContentPosition)
    if changed then
        target.constrainContentPosition = input
    end

    input, changed = drawEditorCheckbox('useInternalMask', target.useInternalMask)
    if changed then
        target.useInternalMask = input
    end
end

local function drawUniformGridFieldset(target)
    drawEditorGroupCaption('GRID')

    local input, changed = drawEditorEnumInput('orientation', target.orientation, viewData.inkEOrientation, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetOrientation(input)
    end

    input, changed = drawEditorIntegerInput('wrappingWidgetCount', target.wrappingWidgetCount, 1, 1, viewStyle.editorInputHalfWidth)
    if changed then
        target:SetWrappingWidgetCount(input)
    end
end

local function drawGridFieldset(target)
    drawEditorGroupCaption('GRID')

    local input, changed = drawEditorEnumInput('orientation', target.orientation, viewData.inkEOrientation, viewStyle.editorInputHalfWidth)
    if changed then
        target.orientation = input
    end

    input, changed = drawEditorMarginInput('childPadding', target.childPadding, '%.2f', viewStyle.editorInputFullWidth)
    if changed then
        target.childPadding = input
    end

    input, changed = drawEditorVector2Input('childSizeStep', target.childSizeStep, '%.2f', viewStyle.editorInputHalfWidth)
    if changed then
        target.childSizeStep = input
    end
end

local function drawCacheFieldset(target)
    drawEditorGroupCaption('CACHE')

    local input, changed = drawEditorEnumInput('mode', target.mode, viewData.inkCacheMode, viewStyle.editorInputHalfWidth)
    if changed then
        target.mode = input
    end

    input, changed = drawEditorTextInput('externalDynamicTexture', target.externalDynamicTexture.value, viewStyle.editorInputHalfWidth)
    if changed then
        target.externalDynamicTexture = input
    end

    input, changed = drawEditorVector2Input('innerScale', target.innerScale, '%.2f', viewStyle.editorInputHalfWidth)
    if changed then
        target.innerScale = input
    end
end

local function drawContextInfo(context)
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
    ImGui.Text('Layer:')
    ImGui.PopStyleColor()
    ImGui.SameLine()
    ImGui.Text(context.spawnInfo.layerName.value)
    if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
        ImGui.SetClipboardText(context.spawnInfo.layerName.value)
    end

    if context.spawnInfo.gameControllerName.hash_lo > 0 then
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
        ImGui.Text('Game Controller:')
        ImGui.PopStyleColor()
        ImGui.SameLine()
        ImGui.Text(context.spawnInfo.gameControllerName.value)
        if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
            ImGui.SetClipboardText(context.spawnInfo.gameControllerName.value)
        end
    end

    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
    ImGui.Text('Input Context:')
    ImGui.PopStyleColor()
    ImGui.SameLine()
    ImGui.Text(context.spawnInfo.inputContext.value)
    if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
        ImGui.SetClipboardText(context.spawnInfo.inputContext.value)
    end

    if context.window then
        if context.window.name.hash_hi > 0 then
            ImGui.Spacing()

            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
            ImGui.Text('HUD Entry:')
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.Text(context.window.name.value)
            if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
                ImGui.SetClipboardText(context.window.name.value)
            end

            if context.window.slot.hash_hi > 0 then
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
                ImGui.Text('HUD Slot:')
                ImGui.PopStyleColor()
                ImGui.SameLine()
                ImGui.Text(context.window.slot.value)
                if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
                    ImGui.SetClipboardText(context.window.slot.value)
                end
            end
        elseif IsDefined(context.window.entity) then
            ImGui.Spacing()

            local entityType = inspectionSystem:GetTypeName(context.window.entity).value
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
            ImGui.Text('Entity Type:')
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.Text(entityType)
            if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
                ImGui.SetClipboardText(entityType)
            end

            local entityID = ('%u'):format(context.window.entity:GetEntityID().hash)
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
            ImGui.Text('Entity ID:')
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.Text(entityID)
            if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
                ImGui.SetClipboardText(entityID)
            end

            local templateRef = inspectionSystem:GetTemplatePath(context.window.entity)
            local templatePath = inspectionSystem:ResolveResourcePath(templateRef.hash)
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
            ImGui.Text('Entity Template:')
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.TextWrapped(templatePath)
            if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
                ImGui.SetClipboardText(templatePath)
            end

            -- TODO: Component name
        end
    end

    if context.spawnInfo.libraryPathHash ~= 0 then
        local libraryPath = inspectionSystem:ResolveResourcePath(context.spawnInfo.libraryPathHash)
        if libraryPath ~= '' then
            ImGui.Spacing()

            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
            ImGui.Text('Library Path:')
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.TextWrapped(libraryPath)
            if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
                ImGui.SetClipboardText(libraryPath)
            end

            if context.spawnInfo.libraryItemName.hash_lo > 0 then
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
                ImGui.Text('Library Item:')
                ImGui.PopStyleColor()
                ImGui.SameLine()
                ImGui.Text(context.spawnInfo.libraryItemName.value)
                if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
                    ImGui.SetClipboardText(context.spawnInfo.libraryItemName.value)
                end
            end
        end
    end

    if context.namePathStr then
        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
        ImGui.Text('Name Path:')
        ImGui.PopStyleColor()
        ImGui.SameLine()
        ImGui.TextWrapped(context.namePathStr)
        if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
            ImGui.SetClipboardText(context.namePathStr)
        end

        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
        ImGui.Text('Index Path:')
        ImGui.PopStyleColor()
        ImGui.SameLine()
        ImGui.TextWrapped(context.indexPathStr)
        if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
            ImGui.SetClipboardText(context.indexPathStr)
        end
    end
end

local function drawEditorContent()
    if not viewState.openSelectedWidgetInEditor then
        return
    end

    if not inspector.target or inspector.target.scope == 'layer' then
        return
    end

    if not IsDefined(inspector.target.widget) then
        return
    end

    ImGui.Separator()
    ImGui.Spacing()

    local widget = inspector.target.widget
    local targetType = inspectionSystem:GetTypeName(widget).value
    ImGui.Text(targetType)
    if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
        ImGui.SetClipboardText(targetType)
    end

    if userState.selectedTab == MainTab.Pick then
        ImGui.SameLine()
        local label = 'Open in tree'
        local labelW = ImGui.CalcTextSize(label)
        local paddingX = ImGui.GetStyle().FramePadding.x * 2
        local regionW = ImGui.GetContentRegionMax()
        ImGui.SetCursorPosX(regionW - textW - paddingX)
        if ImGui.Button(label) then
            userState.selectedTab = MainTab.Inspect
            viewState.isFirstOpen = true
        end
    end

    ImGui.Spacing()
    ImGui.BeginTabBar('##EditorTabBar')

    local firstTabLabel = inspector.context == 'window' and ' Window ' or ' Widget '
    local firstTabFlags = ImGuiTabItemFlags.None

    if viewState.preserveCurrentEditorTab and viewState.isEditorFirstTabOpen then
        firstTabFlags = ImGuiTabItemFlags.SetSelected
    end

    if ImGui.BeginTabItem(firstTabLabel, firstTabFlags) then
        viewState.isEditorFirstTabOpen = true

        local mergeAppearanceGroup = false

        ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
        ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)

        ImGui.BeginChildFrame(3, viewStyle.windowFrameWidth, userState.inspectorPropRows * viewStyle.editorInputHeight)
        ImGui.Spacing()

        ImGui.PopStyleColor()
        ImGui.PopStyleVar(2)

        drawGeneralFieldset(widget)

        if widget:IsA('inkTextWidget') then
            drawTextContentFieldset(widget)
            drawTextSettingsFieldset(widget)
        end

        if widget:IsA('inkImageWidget') then
            drawImageContentFieldset(widget)
            drawImageSettingsFieldset(widget)
        end

        if widget:IsA('inkVideoWidget') then
            drawVideoFieldset(widget)
        end

        if widget:IsA('inkCacheWidget') then
            drawCacheFieldset(widget)
        end

        if widget:IsA('inkMaskWidget') then
            drawMaskFieldset(widget)
        end

        if widget:IsA('inkScrollAreaWidget') then
            drawScrollAreaFieldset(widget)
        end

        if widget:IsA('inkUniformGridWidget') then
            drawUniformGridFieldset(widget)
        end

        if widget:IsA('inkGridWidget') then
            drawGridFieldset(widget)
        end

        if widget:IsA('inkShapeWidget') then
            drawShapeFieldset(widget)
            mergeAppearanceGroup = true
        end

        if widget:IsA('inkQuadShapeWidget') then
            drawQuadShapeFieldset(widget)
        end

        if widget:IsA('inkCircleWidget') then
            drawCircleFieldset(widget)
            mergeAppearanceGroup = true
        end

        if widget:IsA('inkBorderWidget') then
            drawBorderFieldset(widget)
            mergeAppearanceGroup = true
        end

        if widget:IsA('inkGradientWidget') then
            drawGradientFieldset(widget)
        end

        if widget:IsA('inkLinePatternWidget') then
            drawLinePatternFieldset(widget)
        end

        drawAppearanceFieldset(widget, mergeAppearanceGroup)
        drawLayoutFieldset(widget)
        drawTransformFieldset(widget)
        drawEffectsFieldset(widget)
        drawStyleFieldset(widget)

        if widget:IsA('inkCompoundWidget') then
            drawContainerFieldset(widget)
        end

        drawInteractionFieldset(widget)
        drawLogicFieldset(widget)

        ImGui.EndChildFrame()
        ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem(' Context ', ImGuiTabItemFlags.None) then
        viewState.isEditorFirstTabOpen = false
        drawContextInfo(inspector.target)
        ImGui.EndTabItem()
    end

    ImGui.EndTabBar()

    viewState.preserveCurrentEditorTab = false
end

-- GUI :: Inspector --

local function cloneWidget(target)
    local clone = inspectionSystem:CloneObject(target)
    if clone:IsA('inkImageWidget') then
        clone:SetAtlasResource(target.textureAtlas)
    end
    return clone
end

local function drawInspectorTreeNode(node, scope)
    local hash, target, targetOwner, hasChildren
    if scope then
        target = node.handle
        if scope == 'window' then
            if node.name.hash_hi > 0 then
                targetOwner = node.name.value
            elseif IsDefined(node.entity) then
                targetOwner = node.entity:GetClassName().value
            end
        elseif scope == 'layer' then
            hasChildren = #node.windows > 0
        end
    else
        target = node
    end

    local caption = describeTarget(target, true, true)
    if targetOwner then
        caption = caption .. ' @ ' .. targetOwner
    end

    if hash == nil then
        hash = inspectionSystem:GetObjectHash(target)
    end

    local nodeFlags = ImGuiTreeNodeFlags.SpanFullWidth
        + ImGuiTreeNodeFlags.OpenOnArrow + ImGuiTreeNodeFlags.OpenOnDoubleClick

    if hasChildren == nil and inspectionSystem:IsInstanceOf(target, 'inkCompoundWidget') then
        hasChildren = target:GetNumChildren() > 0
    end

    if not hasChildren then
        nodeFlags = nodeFlags + ImGuiTreeNodeFlags.Leaf
    end

    if inspector.target then
        if inspector.target.hash == hash then
            nodeFlags = nodeFlags + ImGuiTreeNodeFlags.Selected
            if viewState.openSelectedWidgetInTree then
                ImGui.SetScrollHereY()
            end
        end
        if viewState.openSelectedWidgetInTree and viewState.openSelectedWidgetInTree[tonumber(hash)] then
            ImGui.SetNextItemOpen(true)
        end
    end

    local expanded = ImGui.TreeNodeEx(caption .. '##' .. tostring(hash), nodeFlags)

    if ImGui.IsItemClicked() and not ImGui.IsItemToggledOpen() then
        selectInspectedTarget(node, scope)

        viewState.preserveCurrentEditorTab = true
    end

    if scope ~= 'layer' and ImGui.BeginPopupContextItem('##InspectorContextMenu:' .. tostring(hash)) then
        local isWidget = not target:IsA('inkWindow')
        local isContainer = target:IsA('inkCompoundWidget')

        if viewState.clipboard and IsDefined(viewState.clipboard.widget) then
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.contextCaptionColor)
            ImGui.SetWindowFontScale(viewStyle.contextCaptionSize)
            ImGui.Text(describeTarget(viewState.clipboard.widget))
            ImGui.SetWindowFontScale(1.0)
            ImGui.PopStyleColor()

            viewState.clipboard.parent = viewState.clipboard.widget.parentWidget

            local isMoving = viewState.clipboard.move or false
            local isMovingAllowed = true
            if isWidget and isMoving and viewState.clipboard.widget:IsA('inkCompoundWidget') then
                local parent = target
                while not parent:IsA('inkWindow') do
                    if inspectionSystem:GetObjectHash(parent) == viewState.clipboard.hash then
                        isMovingAllowed = false
                        break
                    end
                    parent = parent.parentWidget
                end
            end

            if not isMoving or isMovingAllowed then
                local parent = target.parentWidget
                local isSameParent = inspectionSystem:GetObjectHash(viewState.clipboard.parent) == hash
                local isInsideSameParent = inspectionSystem:GetObjectHash(parent) == inspectionSystem:GetObjectHash(viewState.clipboard.parent)

                if isContainer and (not isSameParent or not isMoving) then
                    if isMoving then
                        if ImGui.MenuItem('Move into') then
                            viewState.clipboard.widget:Reparent(target, -1)
                            viewState.clipboard = nil
                        end
                    else
                        if ImGui.MenuItem('Paste into') then
                            local newWidget = cloneWidget(viewState.clipboard.widget)
                            newWidget:Reparent(target, -1)
                            viewState.clipboard = nil
                        end
                    end
                end

                if isWidget then
                    local relativeIndex
                    if isMoving then
                        if ImGui.MenuItem('Move before') then
                            relativeIndex = 0
                        end
                        if ImGui.MenuItem('Move after') then
                            relativeIndex = 1
                        end
                        if relativeIndex then
                            local targetIndex = getChildIndex(target, hash)
                            if isInsideSameParent then
                                parent:ReorderChild(viewState.clipboard.widget, targetIndex + relativeIndex)
                            else
                                viewState.clipboard.widget:Reparent(parent, targetIndex + relativeIndex)
                            end
                            viewState.clipboard = nil
                        end
                    else
                        if ImGui.MenuItem('Paste before') then
                            relativeIndex = 0
                        end
                        if ImGui.MenuItem('Paste after') then
                            relativeIndex = 1
                        end
                        if relativeIndex then
                            local targetIndex = getChildIndex(target, hash)
                            local newWidget = cloneWidget(viewState.clipboard.widget)
                            newWidget:Reparent(parent, targetIndex + relativeIndex)
                            viewState.clipboard = nil
                        end
                    end
                end
            else
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
                ImGui.Text('Can\'t move into itself')
                ImGui.PopStyleColor()
            end

            if isContainer or isWidget then
                ImGui.Spacing()
                ImGui.Separator()
                ImGui.Spacing()
            end
        end

        if isWidget then
            if ImGui.MenuItem('Copy') then
                viewState.clipboard = {
                    widget = target,
                    hash = hash,
                    copy = true,
                }
            end
            if ImGui.MenuItem('Cut') then
                viewState.clipboard = {
                    widget = target,
                    hash = hash,
                    move = true,
                }
            end
            if ImGui.MenuItem('Remove') then
                target.parentWidget:RemoveChild(target)
                viewState.clipboard = nil
            end

            if isContainer then
                ImGui.Spacing()
                ImGui.Separator()
                ImGui.Spacing()
            end
        end

        if isContainer then
            if ImGui.BeginMenu('Create') then
                for _, widgetType in ipairs(viewData.widgetTypes) do
                    if ImGui.MenuItem(widgetType) then
                        local newWidget = NewObject(widgetType)
                        newWidget:Reparent(target, -1)
                        selectInspectedTarget(newWidget)
                        viewState.clipboard = nil
                    end
                end
                ImGui.EndMenu()
            end
        end

        ImGui.EndPopup()
    end

    if expanded then
        if hasChildren then
            if scope and scope == 'layer' then
                for _, window in ipairs(node.windows) do
                    drawInspectorTreeNode(window, 'window')
                end
            else
                for _, widget in ipairs(target.children.children) do
                    drawInspectorTreeNode(widget)
                end
            end
        end
        ImGui.TreePop()
    end
end

local function drawInspectorContent()
    if not inspector.layers then
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
        ImGui.Text('Initializing...')
        ImGui.PopStyleColor()
        return
    end

    ImGui.AlignTextToFramePadding()
    ImGui.Text('Show:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.inspectorFilterWidth)
    local filterIndex, filterChanged = ImGui.Combo('##LayerFilter', LayerFilter.values[userState.layerFilter] - 1, viewData.layerFilterOptions, #viewData.layerFilterOptions)
    if filterChanged then
        userState.layerFilter = LayerFilter.values[filterIndex + 1]
    end

    if inspector.target --[[and inspector.target.scope ~= 'layer']] then
        ImGui.SameLine()
        if ImGui.Button('Scroll to selection') then
            viewState.openSelectedWidgetInTree = true
        end
    end

    ImGui.SameLine()
    if ImGui.Button('Collapse all') then
        userState.inspectorTreeID = userState.inspectorTreeID + 1
    end

    --ImGui.SameLine()
    --if ImGui.Button('Purge orphans') then
    --    collectgarbage()
    --end

    if viewState.openSelectedWidgetInTree == true and inspector.target then
        viewState.openSelectedWidgetInTree = inspector.target.hashPathMap
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)
    ImGui.BeginChildFrame(1, viewStyle.windowFrameWidth, userState.inspectorTreeRows * ImGui.GetFrameHeightWithSpacing(), ImGuiWindowFlags.HorizontalScrollbar)
    ImGui.PushID(userState.inspectorTreeID)
    for _, layer in ipairs(inspector.layers) do
        if layer.isActive or userState.layerFilter == LayerFilter.AllLayers then
            drawInspectorTreeNode(layer, 'layer')
        end
    end
    ImGui.PopID()
    ImGui.EndChildFrame()
    ImGui.PopStyleColor()
    ImGui.PopStyleVar(2)

    viewState.openSelectedWidgetInTree = false
    viewState.openSelectedWidgetInEditor = true
end

-- GUI :: Picker --

local function drawPickerContent(isModal)
    if not picker.target then
        local isHotkeyBound = IsBound('ToggleWidgetPicker')
        ImGui.TextWrapped('To collect widgets under cursor:')
        local step = 1
        if not isHotkeyBound then
            ImGui.Text(('  %d. Configure Widget Picker hotkey'):format(step))
            step = step + 1
        end
        ImGui.Text(('  %d. Close Cyber Engine Tweaks overlay'):format(step))
        step = step + 1
        if isHotkeyBound then
            ImGui.Text(('  %d. Activate Widget Picker using hotkey (%s)'):format(step, GetBind('ToggleWidgetPicker')))
        else
            ImGui.Text(('  %d. Activate Widget Picker using new hotkey'):format(step))
        end
        viewState.openSelectedWidgetInEditor = false
        return
    end

    ImGui.Text(picker.target.layerName)
    --ImGui.SameLine()
    --ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
    --ImGui.Text('/')
    --ImGui.PopStyleColor()
    --ImGui.SameLine()
    --ImGui.Text(picker.target.windowName)

    if IsDefined(picker.target.entity) then
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
        ImGui.Text('@')
        ImGui.PopStyleColor()
        ImGui.SameLine()
        ImGui.Text(picker.target.entity:GetClassName().value)
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    if #picker.results == 0 then
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
        ImGui.Text('No targets')
        ImGui.PopStyleColor()
        viewState.openSelectedWidgetInEditor = false
        return
    end

    if not isModal then
        ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
        ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)
        ImGui.BeginChildFrame(2, viewStyle.windowFrameWidth, math.min(#picker.results, userState.pickerResultListRows) * ImGui.GetFrameHeightWithSpacing())
    end

    local isSelectedWidgetFound = false

    for _, result in ipairs(picker.results) do
        local widget = result.handle
        if IsDefined(widget) then
            local itemCaption = describeTarget(widget, true, true)

            if result.isInteractive then
                itemCaption = itemCaption .. ' ^'
            end

            local isItemSelected = inspector.target and inspector.target.hash == result.hash or false

            ImGui.Selectable(itemCaption, not isModal and isItemSelected, ImGuiSelectableFlags.SpanAllColumns)

            if ImGui.IsItemClicked() then
                selectInspectedTarget(widget)

                viewState.preserveCurrentEditorTab = true
                viewState.openSelectedWidgetInTree = true

                isItemSelected = true
            end

            if isItemSelected then
                isSelectedWidgetFound = true
            end
        end
    end

    if not isModal then
        ImGui.EndChildFrame()
        ImGui.PopStyleColor()
        ImGui.PopStyleVar(2)
    end

    if not isModal and isSelectedWidgetFound then
        viewState.openSelectedWidgetInEditor = true
    end
end

-- GUI :: Settings --

local function drawSettingsContent()
    local state, changed

    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.SetWindowFontScale(viewStyle.groupCaptionSize)
    ImGui.Text('TOOL WINDOW')
    ImGui.SetWindowFontScale(1.0)
    ImGui.PopStyleColor()

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Window snapping:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsMiddleComboRowWidth - ImGui.GetCursorPosX())
    state, changed = ImGui.Combo('##WindowSnapping', WindowSnapping.values[userState.windowSnapping] - 1, viewData.windowSnappingOptions, #viewData.windowSnappingOptions)
    if changed then
        userState.windowSnapping = WindowSnapping.values[state + 1]
    end
    ImGui.EndGroup()

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.SetWindowFontScale(viewStyle.groupCaptionSize)
    ImGui.Text('WIDGET PICKER')
    ImGui.SetWindowFontScale(1.0)
    ImGui.PopStyleColor()

    ImGui.Spacing()

    state, changed = ImGui.Checkbox('Deactivate picker when opening the console', userState.disablePickerOnConsoleOpen)
    if changed then
        userState.disablePickerOnConsoleOpen = state
    end

    state, changed = ImGui.Checkbox('Auto enable cursor if layer doesn\'t have one', userState.enforcePointerOnActivation)
    if changed then
        userState.enforcePointerOnActivation = state
    end

    state, changed = ImGui.Checkbox('Auto snap picker overlay based on cursor position', userState.autoSnapOnScreenDisplay)
    if changed then
        userState.autoSnapOnScreenDisplay = state
    end

    viewState.openSelectedWidgetInEditor = false
end

-- GUI :: Hotkeys --

local function drawHotkeysContent()
    app.drawHotkeys(moduleID)

    viewState.openSelectedWidgetInEditor = false
end

-- GUI :: Drawing --

local function getScreenDescriptor()
    local screen = {}
    screen.width, screen.height = GetDisplayResolution()

    screen.centerX = screen.width / 2
    screen.centerY = screen.height / 2

    screen[1] = { x = 0, y = 0 }
    screen[2] = { x = screen.width - 1, y = 0 }
    screen[3] = { x = screen.width - 1, y = screen.height - 1 }
    screen[4] = { x = 0, y = screen.height }

    return screen
end

local clampScreenPoint = false

local function setScreenClamping(enabled)
    clampScreenPoint = enabled
end

local function getScreenPoint(screen, point)
    local projected = inspectionSystem:ProjectWorldPoint(point)

    local result = {
        x = projected.x,
        y = -projected.y,
        off = projected.w <= 0.0 or projected.z <= 0.0,
    }

    if projected.w > 0.0 then
        result.x = result.x / projected.w
        result.y = result.y / projected.w
    end

    if clampScreenPoint then
        result.x = MathEx.Clamp(result.x, -0.995, 0.995)
        result.y = MathEx.Clamp(result.y, -0.999, 0.999)
        result.off = false
    end

    result.x = screen.centerX + (result.x * screen.centerX)
    result.y = screen.centerY + (result.y * screen.centerY)

    return result
end

local function drawQuad(quad, color, thickness)
    if thickness == nil then
        ImGui.ImDrawListAddQuadFilled(ImGui.GetWindowDrawList(),
            quad[1].x, quad[1].y,
            quad[2].x, quad[2].y,
            quad[3].x, quad[3].y,
            quad[4].x, quad[4].y,
            color)
    else
        ImGui.ImDrawListAddQuad(ImGui.GetWindowDrawList(),
            quad[1].x, quad[1].y,
            quad[2].x, quad[2].y,
            quad[3].x, quad[3].y,
            quad[4].x, quad[4].y,
            color, thickness)
    end
end

local function drawRectangle(rect, color, thickness)
    if thickness == nil then
        ImGui.ImDrawListAddRectFilled(ImGui.GetWindowDrawList(),
            rect.x, rect.y,
            rect.x + rect.width, rect.y + rect.height,
            color)
    else
        ImGui.ImDrawListAddRect(ImGui.GetWindowDrawList(),
            rect.x, rect.y,
            rect.x + rect.width, rect.y + rect.height,
            color, thickness)
    end
end

local function drawText(position, color, size, text)
    ImGui.ImDrawListAddText(ImGui.GetWindowDrawList(), size, position.x, position.y, color, tostring(text))
end

local function drawProjections()
    if not userState.isModuleActive then
        return
    end

    if next(highlight.projections) == nil then
        return
    end

    local screen = getScreenDescriptor(camera)

    ImGui.SetNextWindowSize(screen.width, screen.height, ImGuiCond.Always)
    ImGui.SetNextWindowPos(0, 0, ImGuiCond.Always)

    if ImGui.Begin('##RHT:InkTools:Projections', true, viewStyle.projectionWindowFlags) then
        for _, projection in pairs(highlight.projections) do
            if IsDefined(projection.widget) then
                drawRectangle(projection.area, projection.color, 1)
            end
        end
    end
end

-- GUI :: Windows --

local function pushWindowStyle(isModal)
    local windowX, windowY, condition
    local windowSnapping = userState.windowSnapping

    if isModal and userState.autoSnapOnScreenDisplay then
        if viewState.autoWindowSnapping then
            windowSnapping = viewState.autoWindowSnapping
        else
            if windowSnapping ~= WindowSnapping.TopLeft then
                windowSnapping = WindowSnapping.TopRight
            end
        end

        local cursorPos = inspectionSystem:GetPointerScreenPosition()
        local dataRows = 3 + (picker.results and #picker.results or 0)
        local bottomY = viewStyle.windowTopY + viewStyle.windowPaddingY * 2
            + (dataRows * ImGui.GetTextLineHeightWithSpacing())
        local margin = 10 * viewStyle.viewScale

        if cursorPos.Y <= (bottomY + margin) then
            if windowSnapping == WindowSnapping.TopRight then
                if cursorPos.X >= (viewStyle.windowRightX - margin) then
                    windowSnapping = WindowSnapping.TopLeft
                end
            else
                if cursorPos.X <= (viewStyle.windowLeftX + viewStyle.windowFullWidth + margin) then
                    windowSnapping = WindowSnapping.TopRight
                end
            end
        end

        viewState.autoWindowSnapping = windowSnapping
    end

    if windowSnapping == WindowSnapping.Disabled then
        condition = ImGuiCond.FirstUseEver
        windowX = viewStyle.windowDefaultX
        windowY = viewStyle.windowDefaultY
    elseif windowSnapping == WindowSnapping.TopLeft then
        condition = ImGuiCond.Always
        windowX = viewStyle.windowLeftX
        windowY = viewStyle.windowTopY
    elseif windowSnapping == WindowSnapping.TopRight then
        condition = ImGuiCond.Always
        windowX = viewStyle.windowRightX
        windowY = viewStyle.windowTopY
    end

    ImGui.SetNextWindowPos(windowX, windowY, condition)
    ImGui.SetNextWindowSize(viewStyle.windowFullWidth, viewStyle.windowHeight)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, viewStyle.windowPaddingX, viewStyle.windowPaddingY)
end

local function popWindowStyle()
    ImGui.PopStyleVar()
end

local function drawPickerWindow()
    pushWindowStyle(true)
    ImGui.Begin('Ink Inspector##RHT:InkTools:Overlay', viewStyle.pickerWindowFlags)

    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - 2)
    drawPickerContent(true)

    ImGui.End()
    popWindowStyle()
end

local function drawMainWindow()
    pushWindowStyle()

    viewState.isWindowOpen = ImGuiEx.Begin('Ink Inspector##RHT:InkTools:MainWindow', app.canCloseTools(), viewStyle.mainWindowFlags)
    viewState.isWindowExpanded = not ImGui.IsWindowCollapsed()

    if viewState.isWindowOpen and viewState.isWindowExpanded then
        app.drawSharedMenu(moduleID)

        ImGui.BeginTabBar('##RHT:InkTools:MainTabBar')

        local selectedTab
        local featureTabs = {
            { id = MainTab.Inspect, draw = drawInspectorContent },
            { id = MainTab.Pick, draw = drawPickerContent },
            { id = MainTab.Settings, draw = drawSettingsContent },
            { id = MainTab.Hotkeys, draw = drawHotkeysContent },
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

        drawEditorContent()
    end

    ImGui.End()
    popWindowStyle()

    if not viewState.isWindowOpen then
        userState.isModuleActive = false
        userState.isOnScreenDisplayActive = false
        saveUserState()
    end
end

local function onDraw()
    if not userState.isModuleActive then
        return
    end

    if not viewState.isConsoleOpen and not userState.isOnScreenDisplayActive then
        return
    end

    initializeViewStyle()

    if viewState.isConsoleOpen then
        if userState.isModuleActive and viewState.isWindowExpanded then
            --drawProjections()
        end
        drawMainWindow()
    elseif userState.isOnScreenDisplayActive then
        --drawProjections()
        drawPickerWindow()
    end
end

local function onOverlayOpen()
    viewState.isConsoleOpen = true
    if userState.isOnScreenDisplayActive then
        userState.selectedTab = MainTab.Pick
        viewState.isFirstOpen = true
        saveUserState()
    end

    if userState.disablePickerOnConsoleOpen then
        userState.isOnScreenDisplayActive = false
        inspectionSystem:DisablePointerInput()
    end
end

local function onOverlayClose()
    viewState.isConsoleOpen = false
    saveUserState()
end

-- Hotkeys --

local function onTogglePickerHotkey()
    if not viewState.isConsoleOpen then
        userState.isOnScreenDisplayActive = not userState.isOnScreenDisplayActive
        if userState.isOnScreenDisplayActive then
            userState.isModuleActive = true
            if userState.enforcePointerOnActivation then
                inspectionSystem:EnsurePointerInput()
            end
        else
            inspectionSystem:DisablePointerInput()
        end
        saveUserState()
    end
end

local function onTogglePointerHotkey()
    if not viewState.isConsoleOpen then
        inspectionSystem:TogglePointerInput()
    end
end

--local function onSelectNextResultHotkey()
--    if not viewState.isConsoleOpen and userState.isOnScreenDisplayActive then
--        --cycleNextInspectedResult()
--    end
--end
--
--local function onSelectPrevResultHotkey()
--    if not viewState.isConsoleOpen and userState.isOnScreenDisplayActive then
--        --cyclePrevInspectedResult()
--    end
--end

-- Module --

local function isActive()
    return userState.isModuleActive
end

local function setActive(active)
    userState.isModuleActive = active
    if not userState.isModuleActive then
        userState.isOnScreenDisplayActive = false
    end
    saveUserState()
end

local function onInit()
    initializeSystems()
    initializeUserState()
    initializeViewData()

    Cron.Every(0.2, function()
        if userState.isModuleActive then
            if viewState.isConsoleOpen then
                if viewState.isWindowExpanded then
                    if userState.selectedTab == MainTab.Inspect then
                        updateInspector(true)
                    elseif userState.selectedTab == MainTab.Pick then
                        updatePicker(false)
                    end
                end
            elseif userState.isOnScreenDisplayActive then
                updatePicker(true)
            end
        end
        updateHighlights()
    end)
end

local function onShutdown()
    disableHighlights()
    saveUserState()
end

return {
    id = moduleID,
    events = {
        onInit = onInit,
        onShutdown = onShutdown,
        onOverlayOpen = onOverlayOpen,
        onOverlayClose = onOverlayClose,
        onDraw = onDraw,
    },
    tools = {
        { id = 'InkTools', label = 'Ink Inspector', isActive = isActive, setActive = setActive }
    },
    hotkeys = {
        { id = 'ToggleWidgetPicker', group = 'Widget Picker', label = 'Toggle overlay', callback = onTogglePickerHotkey },
        { id = 'TogglePointerInput', group = 'Widget Picker', label = 'Toggle forced cursor', callback = onTogglePointerHotkey },
        --{ id = 'SelectNextResult', group = 'Target Control', label = 'Select next target', callback = onSelectNextResultHotkey },
        --{ id = 'SelectPrevResult', group = 'Target Control', label = 'Select previous target', callback = onSelectPrevResultHotkey },
    },
    publicApi = {
        GetSelectedWidget = function()
            return inspector.target and inspector.target.widget or nil
        end,
    }
}
