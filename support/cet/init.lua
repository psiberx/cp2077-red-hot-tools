local Cron = require('Cron')
local Ref = require('Ref')

local envState = {
    isHotToolsFound = false,
    isTweakXLFound = false,
}

local viewState = {
    isConsoleOpen = false,
    isInspectorOpen = false,
}

local viewStyle = {
    windowX = 0,
    windowY = 300,
    label = 0xff9f9f9f,
    muted = 0xff9f9f9f,
}

local watching = false
local watchedEntities = {}

local inspecting = false
local inspectorTarget
local inspectorData = {}

local targetingSystem
local spatialQuerySystem
local inspectionSystem

local collisionGroups = {
    'Static',
    --'Player',
    'AI',
    'Dynamic',
    'Vehicle',
    --'Tank',
    'Destructible',
    'Terrain',
    'Collider',
    --'Particle',
    --'Ragdoll',
    --'Ragdoll Inner',
    'Debris',
    --'Cloth',
    'PlayerBlocker',
    'VehicleBlocker',
    --'TankBlocker',
    'DestructibleCluster',
    'NPCBlocker',
}

local staticCollisionThreshold = 0.2

local inspectorObjectSchema = {
    { name = 'objectType', label = 'Target Type:' },
    { name = 'collisionGroup', label = 'Target Collision:', format = function(data)
        return ('%s (%.2f)'):format(data.collisionGroup, data.targetDistance)
    end },
    { name = 'recordID', label = 'Record ID:' },
    { name = 'entityID', label = 'Entity ID:', format = '%u' },
    { name = 'deviceClass', label = 'Device Class:' },
    { name = 'templatePath', label = 'Entity Template:', wrap = true },
    { name = 'appearanceName', label = 'Entity Appearance:' },
    { name = 'meshPath', label = 'Mesh Resource:', wrap = true },
    { name = 'meshAppearance', label = 'Mesh Appearance:' },
    { name = 'materialPath', label = 'Material Resource:', wrap = true },
    --{ name = 'communityRef', label = 'Community:', wrap = true },
    { name = 'nodeRef', label = 'World Node:', wrap = true },
    { name = 'sectorPath', label = 'World Sector:', wrap = true },
    --{ name = 'targetDistance', label = 'Distance:', format = '%.2f' },
    --{ name = 'collisionGroup', label = 'Collision Group:' },
}

local inspectorComponentSchema = {
    { name = 'componentName', label = 'Name:' },
    { name = 'componentType', label = 'Type:' },
    { name = 'meshPath', label = 'Mesh Resource:', wrap = true },
    { name = 'morphPath', label = 'Morph Target Resource:', wrap = true },
    { name = 'meshAppearance', label = 'Mesh Appearance:' },
}

local function isEmpty(value)
    return value == nil or value == '' or value == 0
end

local function isNotEmpty(value)
    return value ~= nil and value ~= '' and value ~= 0
end

local function getLookAtTarget(maxDistance)
	local player = GetPlayer()

	if not IsDefined(player) then
        return nil
	end

	if not maxDistance then
		maxDistance = 100
	end

	local from, forward = targetingSystem:GetCrosshairData(player)
	local to = Vector4.new(
		from.x + forward.x * maxDistance,
		from.y + forward.y * maxDistance,
		from.z + forward.z * maxDistance,
		from.w
	)

	local results = {}

	for _, group in ipairs(collisionGroups) do
		local success, trace = spatialQuerySystem:SyncRaycastByCollisionGroup(from, to, group, false, false)

		if success then
			local target = inspectionSystem:GetPhysicsTraceObject(trace)
			if target.resolved then
			    local distance = Vector4.Distance(from, ToVector4(trace.position))
			    if distance > 0 then
                    table.insert(results, {
                        distance = distance,
                        target = target,
                        group = group,
                    })
                end
			end
		end
	end

	if #results == 0 then
		return nil
	end

	local nearest = results[1]

	for i = 2, #results do
		if results[i].distance < nearest.distance then
		    if results[i].group ~= collisionGroups[1] or nearest.distance - results[i].distance > staticCollisionThreshold then
    			nearest = results[i]
            end
		end
	end

	return nearest.target, nearest.group, nearest.distance
end

local function collectComponents(entity)
    local componentList = {}

    for _, component in ipairs(inspectionSystem:GetComponents(entity)) do
        local componentData = {
            componentName = component:GetName().value,
            componentType = component:GetClassName().value,
            meshPath = '',
            morphPath = '',
            meshAppearance = '',
        }

        if component:IsA('entMeshComponent') or component:IsA('entSkinnedMeshComponent') then
            componentData.meshPath = inspectionSystem:ResolveResourcePath(component.mesh.hash)
            componentData.meshAppearance = component.meshAppearance.value

            if isEmpty(componentData.meshPath) then
                componentData.meshPath = ('%u'):format(component.mesh.hash)
            end
        end

        if component:IsA('entMorphTargetSkinnedMeshComponent') then
            componentData.morphPath = inspectionSystem:ResolveResourcePath(component.morphResource.hash)
            componentData.meshAppearance = component.meshAppearance.value

            if isEmpty(componentData.morphPath) then
                componentData.morphPath = ('%u'):format(component.morphResource.hash)
            end
        end

        table.insert(componentList, componentData)
    end

    return componentList
end

local function inspectEntity(target, collisionGroup, targetDistance)
    if not target or not target.resolved then
        inspecting = false
        inspectorTarget = nil
        return
    end

    if inspectorTarget then
        if inspectorTarget.hash == target.hash then
            inspectorData.targetDistance = targetDistance
            return
        end
    end

    local data = {}
    local object = target.object

    if target.scriptable then
        if target:IsA('entEntity') then
            data.entityID = object:GetEntityID().hash
            data.nodeRef = inspectionSystem:ResolveNodeRefFromNodeID(data.entityID)
            data.sectorPath = inspectionSystem:ResolveSectorPathFromNodeID(data.entityID)

            data.appearanceName = object:GetCurrentAppearanceName().value
            data.components = collectComponents(object)
            data.hasComponents = (#data.components > 0)

            local templatePath = object:GetTemplatePath().resource
            data.templatePath = inspectionSystem:ResolveResourcePath(templatePath.hash)
            if isEmpty(data.templatePath) and isNotEmpty(templatePath.hash) then
                data.templatePath = ('%u'):format(templatePath.hash)
            end
            
            if isEmpty(data.nodeRef) then
                local communityID = inspectionSystem:ResolveCommunityRefFromEntityID(object:GetEntityID())
                if communityID.hash ~= 0 then
                    data.nodeRef = inspectionSystem:ResolveNodeRefFromNodeID(communityID.hash)
                    if isEmpty(data.sectorPath) then
                        data.sectorPath = inspectionSystem:ResolveSectorPathFromNodeID(communityID.hash)
                    end
                end
            end

            if target:IsA('gameObject') then
                local recordID = object:GetTDBID()
                if TDBID.IsValid(recordID) then
                    data.recordID = TDBID.ToStringDEBUG(recordID)
                end
            end
        end
    else
        data.sectorPath = inspectionSystem:ResolveSectorPathFromNode(object)

        if target:IsA('worldMeshNode') or target:IsA('worldInstancedMeshNode') then
            data.meshPath = inspectionSystem:ResolveResourcePath(object.mesh.hash)
            data.meshAppearance = object.meshAppearance.value
        end

        if target:IsA('worldStaticDecalNode') then
            data.materialPath = inspectionSystem:ResolveResourcePath(object.material.hash)
        end

        if target:IsA('worldEntityNode') then
            data.templatePath = inspectionSystem:ResolveResourcePath(object.entityTemplate.hash)
            data.appearanceName = object.appearanceName.value
        end

        if target:IsA('worldDeviceNode') then
            data.deviceClass = object.deviceClassName.value
        end
    end

    if not data.objectType then
        data.objectType = target.type.value
    end

    data.collisionGroup = collisionGroup.value
    data.targetDistance = targetDistance

    inspectorTarget = target
    inspectorData = data
    inspecting = true
end

local function watchEntity(entity)
    if not IsDefined(entity) then
        return
    end

    local key = tostring(entity:GetEntityID().hash)

    watchedEntities[key] = {
        name = ('%s#%s'):format(entity:GetClassName().value, key),
        entity = Ref.Weak(entity),
        components = {},
    }

    if not watching then
        Cron.Every(1.0, function()
            if viewState.isConsoleOpen then
                for _, entry in pairs(watchedEntities) do
                    entry.components = collectComponents(entry.entity)
                end
            end
        end)
        watching = true
    end
end

local function forgetEntity(entity)
    if not IsDefined(entity) then
        return
    end

    local key = tostring(entity:GetEntityID().hash)

    watchedEntities[key] = nil
    collectgarbage()
end

local function initializeEnvState()
    envState.isHotToolsFound = type(RedHotTools) == 'userdata'
    envState.isTweakXLFound = type(TweakXL) == 'userdata'
end

local function initializeWatcher()
    watchEntity(GetPlayer())

    ObserveAfter('PlayerPuppet', 'OnGameAttached', function(this)
        watchEntity(this)
    end)

    ObserveAfter('PlayerPuppet', 'OnDetach', function(this)
        forgetEntity(this)
    end)

    ObserveBefore('gameuiPuppetPreviewGameController', 'OnPreviewInitialized', function(this)
        watchEntity(this:GetGamePuppet())
    end)

    ObserveBefore('gameuiPuppetPreviewGameController', 'OnUninitialize', function(this)
        if this:IsA('gameuiPuppetPreviewGameController') then
            forgetEntity(this:GetGamePuppet())
        end
    end)

    ObserveAfter('PhotoModePlayerEntityComponent', 'SetupInventory', function(this)
        watchEntity(this.fakePuppet)
    end)

    ObserveBefore('PhotoModePlayerEntityComponent', 'ClearInventory', function(this)
        forgetEntity(this.fakePuppet)
    end)
end

local function initializeInspector()
    targetingSystem = Game.GetTargetingSystem()
    spatialQuerySystem = Game.GetSpatialQueriesSystem()
    inspectionSystem = Game.GetInspectionSystem()

    for i, collisionGroup in ipairs(collisionGroups) do
        collisionGroups[i] = CName(collisionGroup)
    end

    Cron.Every(0.2, function()
        if viewState.isConsoleOpen or viewState.isInspectorOpen then
            inspectEntity(getLookAtTarget())
        end
    end)
end

local function initializeViewStyle()
    if not viewStyle.fontSize then
        viewStyle.fontSize = ImGui.GetFontSize()
        viewStyle.viewScale = viewStyle.fontSize / 13

        viewStyle.windowWidth = 400 * viewStyle.viewScale
        viewStyle.windowHeight = 0
        viewStyle.windowPaddingX = 8 * viewStyle.viewScale
        viewStyle.windowPaddingY = 8 * viewStyle.viewScale

        viewStyle.mainWindowFlags = ImGuiWindowFlags.NoResize
            + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse
        viewStyle.overlayWindowFlags = viewStyle.mainWindowFlags
            + ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoCollapse
            + ImGuiWindowFlags.NoInputs + ImGuiWindowFlags.NoNav

        viewStyle.buttonHeight = 24 * viewStyle.viewScale
    end
end

local function drawField(field, data)
    if isNotEmpty(data[field.name]) then
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.label)
        ImGui.Text(field.label)
        ImGui.PopStyleColor()
        ImGui.SameLine()

        local value = data[field.name]
        if field.format then
            if type(field.format) == 'function' then
                value = field.format(data, field)
            else
                value = (field.format):format(value)
            end
        else
            value = tostring(value)
        end

        if field.wrap then
            ImGui.TextWrapped(value)
        else
            ImGui.Text(value)
        end

        if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
            ImGui.SetClipboardText(value)
        end
    end
end

local function drawComponentsTree(components, maxComponents)
    local visibleComponents = math.min(maxComponents or 10, #components)
    ImGui.BeginChildFrame(1, 0, visibleComponents * ImGui.GetFrameHeightWithSpacing())
    for index, componentData in ipairs(components) do
        if ImGui.TreeNodeEx(('[%d] %s'):format(index, componentData.componentName), ImGuiTreeNodeFlags.SpanFullWidth) then
            for _, field in ipairs(inspectorComponentSchema) do
                drawField(field, componentData)
            end
            ImGui.TreePop()
        end
    end
    ImGui.EndChildFrame()
end

local function drawInspector(withComponents)
    if withComponents == nil then
        withComponents = true
    end

    if inspecting then
        ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
        ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)

        for _, field in ipairs(inspectorObjectSchema) do
            drawField(field, inspectorData)
        end

        if inspectorData.hasComponents then
            if withComponents then
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.label)
                ImGui.Text('Components:')
                ImGui.PopStyleColor()
                drawComponentsTree(inspectorData.components, 10)
            else
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.label)
                ImGui.Text(('Components (%d)'):format(#inspectorData.components))
                ImGui.PopStyleColor()
            end
        end

        ImGui.PopStyleColor()
        ImGui.PopStyleVar(2)
    else
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.muted)
        ImGui.TextWrapped('No target.')
        ImGui.PopStyleColor()
    end
end

local function drawInspectorWindow()
    ImGui.Begin('Red Hot Tools', viewStyle.overlayWindowFlags)
    drawInspector(false)
    ImGui.End()
end

local function drawMainWindow()
    if ImGui.Begin('Red Hot Tools', viewStyle.mainWindowFlags) then
        ImGui.BeginTabBar('Red Hot Tools TabBar')

		if ImGui.BeginTabItem(' Reload ') then
            ImGui.Text('Archives')
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.muted)
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
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.muted)
            ImGui.TextWrapped('Hot load scripts from r6/scripts.')
            ImGui.PopStyleColor()
            ImGui.Spacing()

            if ImGui.Button('Reload scripts', viewStyle.windowWidth, viewStyle.buttonHeight) then
                RedHotTools.ReloadScripts()
            end

            if envState.isTweakXLFound then
                ImGui.Spacing()
                ImGui.Separator()
                ImGui.Spacing()

                ImGui.Text('Tweaks')
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.muted)
                ImGui.TextWrapped('Hot load tweaks from r6/tweaks and scriptable tweaks.')
                ImGui.PopStyleColor()
                ImGui.Spacing()

                if ImGui.Button('Reload tweaks', viewStyle.windowWidth, viewStyle.buttonHeight) then
                    RedHotTools.ReloadTweaks()
                end
            end

			ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem(' Player ') then
            ImGui.Spacing()
            if watching then
                ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
                ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
                ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)

                for _, entry in pairs(watchedEntities) do
                    if ImGui.CollapsingHeader(entry.name) then
                        drawComponentsTree(entry.components, 10)
                    end
                end

                ImGui.PopStyleColor()
                ImGui.PopStyleVar(2)
            else
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.muted)
                ImGui.TextWrapped('No player entities.')
                ImGui.PopStyleColor()
            end
            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem(' Lookup ') then
            ImGui.Spacing()
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.muted)
            ImGui.TextWrapped('Enter reference string or hash...')
            ImGui.PopStyleColor()
            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem(' Inspect ') then
            ImGui.Spacing()
            drawInspector()
            ImGui.EndTabItem()
        end
    end
    ImGui.End()
end

registerForEvent('onInit', function()
    initializeEnvState()

    if envState.isHotToolsFound then
        initializeWatcher()
        initializeInspector()
    end
end)

registerForEvent('onOverlayOpen', function()
    viewState.isConsoleOpen = true
end)

registerForEvent('onOverlayClose', function()
    viewState.isConsoleOpen = false
end)

registerForEvent('onDraw', function()
    if not envState.isHotToolsFound then
        return
    end

    if not viewState.isConsoleOpen and not viewState.isInspectorOpen then
        return
    end

    initializeViewStyle()

    ImGui.SetNextWindowPos(viewStyle.windowX, viewStyle.windowY, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(viewStyle.windowWidth + viewStyle.windowPaddingX * 2 - 1, viewStyle.windowHeight)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, viewStyle.windowPaddingX, viewStyle.windowPaddingY)

    if viewState.isConsoleOpen then
        drawMainWindow()
    elseif viewState.isInspectorOpen then
        drawInspectorWindow()
    end

    ImGui.PopStyleVar()
end)

registerForEvent('onUpdate', function(delta)
	Cron.Update(delta)
end)

registerHotkey('ToggleInspector', 'Toggle inspector window', function()
    if not viewState.isConsoleOpen then
        viewState.isInspectorOpen = not viewState.isInspectorOpen
    end
end)
