local Cron = require('Cron')
local Ref = require('Ref')

local envState = {
    isHotToolsFound = false,
    isTweakXLFound = false,
}

local viewState = {
    isConsoleOpen = false,
    isInspectorOpen = false,
    isLookupOpen = false,
    isAlwaysOnScreen = false,
    lookupInput = '',
    maxInputLen = 256,
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

local lookupResult = {}

local targetingSystem
local spatialQuerySystem
local inspectionSystem

local collisionGroups = {
    { name = 'Static', threshold = 0.0, tolerance = 0.2 },
    --{ name = 'Cloth', threshold = 0.2, tolerance = 0.0 },
    --{ name = 'Player', threshold = 0.2, tolerance = 0.0 },
    { name = 'AI', threshold = 0.0, tolerance = 0.0 },
    { name = 'Dynamic', threshold = 0.0, tolerance = 0.0 },
    { name = 'Vehicle', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'Tank', threshold = 0.0, tolerance = 0.0 },
    { name = 'Destructible', threshold = 0.0, tolerance = 0.0 },
    { name = 'Terrain', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'Collider', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'Particle', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'Ragdoll', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'Ragdoll Inner', threshold = 0.0, tolerance = 0.0 },
    { name = 'Debris', threshold = 0.0, tolerance = 0.0 },
    { name = 'PlayerBlocker', threshold = 0.0, tolerance = 0.0 },
    { name = 'VehicleBlocker', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'TankBlocker', threshold = 0.0, tolerance = 0.0 },
    { name = 'DestructibleCluster', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'NPCBlocker', threshold = 0.0, tolerance = 0.0 },
    { name = 'Visibility', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'Audible', threshold = 0.0, tolerance = 0.0 },
    { name = 'Interaction', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'Shooting', threshold = 0.2, tolerance = 0.0 },
    { name = 'Water', threshold = 0.0, tolerance = 0.0 },
    { name = 'NetworkDevice', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'NPCTraceObstacle', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'PhotoModeCamera', threshold = 0.0, tolerance = 0.0 },
    { name = 'FoliageDestructible', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'NPCNameplate', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'NPCCollision', threshold = 0.0, tolerance = 0.0 },
}

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
    --{ name = 'communityID', label = 'Community ID:', format = '%u' },
    --{ name = 'communityRef', label = 'Community Ref:', wrap = true },
    { name = 'nodeID', label = 'World Node ID:', format = '%u' },
    { name = 'nodeRef', label = 'World Node Ref:', wrap = true },
    { name = 'nodeIndex', label = 'World Node Index:', format = '%d', validate = function(data)
        return data and data.nodeIndex > 0
    end },
    { name = 'sectorPath', label = 'World Sector:', wrap = true },
    { name = 'resourcePath', label = 'Resource:', wrap = true },
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

	if not IsDefined(player) or IsDefined(GetMountedVehicle(player)) then
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
		local success, trace = spatialQuerySystem:SyncRaycastByCollisionGroup(from, to, group.name, false, false)

		if success then
			local target = inspectionSystem:GetPhysicsTraceObject(trace)
			if target.resolved then
			    local distance = Vector4.Distance(from, ToVector4(trace.position))
			    if distance > group.threshold then
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
	    local diff = nearest.distance - results[i].distance
		if diff > results[i].group.tolerance then
            nearest = results[i]
		end
	end

	return nearest.target, nearest.group.name, nearest.distance
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

local function inspectTarget(target, collisionGroup, targetDistance)
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

            local templatePath = object:GetTemplatePath().resource
            data.templatePath = inspectionSystem:ResolveResourcePath(templatePath.hash)
            data.appearanceName = object:GetCurrentAppearanceName().value
            if isEmpty(data.templatePath) and isNotEmpty(templatePath.hash) then
                data.templatePath = ('%u'):format(templatePath.hash)
            end

            if data.entityID > 0xffffff then
                data.nodeID = data.entityID
            else
                local communityID = inspectionSystem:ResolveCommunityIDFromEntityID(object:GetEntityID())
                if communityID.hash > 0xffffff then
                    data.nodeID = communityID.hash
                end
            end

            if isNotEmpty(data.nodeID) then
                data.nodeRef = inspectionSystem:ResolveNodeRefFromNodeHash(data.nodeID)
                local sectorLocation = inspectionSystem:ResolveSectorFromNodeHash(data.nodeID)
                if sectorLocation.sectorHash ~= 0 then
                    data.sectorPath = inspectionSystem:ResolveResourcePath(sectorLocation.sectorHash)
                    data.nodeIndex = sectorLocation.nodeIndex
                end
            end

            if target:IsA('gameObject') then
                local recordID = object:GetTDBID()
                if TDBID.IsValid(recordID) then
                    data.recordID = TDBID.ToStringDEBUG(recordID)
                end
            end

            data.components = collectComponents(object)
            data.hasComponents = (#data.components > 0)
        end
    else
        local sectorLocation = inspectionSystem:ResolveSectorFromNode(object)
        if sectorLocation.sectorHash ~= 0 then
            data.sectorPath = inspectionSystem:ResolveResourcePath(sectorLocation.sectorHash)
            data.nodeIndex = sectorLocation.nodeIndex
        end

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

local function lookupTarget(lookupInput)
    if isEmpty(lookupInput) then
        lookupResult = {}
        return
    end

    if lookupResult.input == lookupInput then
        return
    end

    local data = {}

    local lookupHash = lookupInput:match('^(%d+)ULL$') or lookupInput:match('^(%d+)$')
    if lookupHash ~= nil then
        local hash = loadstring('return ' .. lookupHash .. 'ULL', '')()
        data.resourcePath = inspectionSystem:ResolveResourcePath(hash)
        data.nodeRef = inspectionSystem:ResolveNodeRefFromNodeHash(hash)
        if isNotEmpty(data.nodeRef) then
            data.nodeID = hash
        end
    else
        local hash = inspectionSystem:ResolveNodeRefHash(lookupInput)
        if isNotEmpty(hash) then
            data.nodeRef = inspectionSystem:ResolveNodeRefFromNodeHash(hash)
            if isNotEmpty(data.nodeRef) then
                data.nodeID = hash
            end
        end
    end

    if isNotEmpty(data.nodeID) then
        local sectorLocation = inspectionSystem:ResolveSectorFromNodeHash(data.nodeID)
        if sectorLocation.sectorHash ~= 0 then
            data.sectorPath = inspectionSystem:ResolveResourcePath(sectorLocation.sectorHash)
            data.nodeIndex = sectorLocation.nodeIndex
        end
    end

    data.input = lookupInput
    data.empty = isEmpty(data.resourcePath) and isEmpty(data.nodeRef) and isEmpty(data.sectorPath)
    data.ready = true

    lookupResult = data
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

    for _, collisionGroup in ipairs(collisionGroups) do
        collisionGroup.name = CName(collisionGroup.name)
    end

    Cron.Every(0.2, function()
        if viewState.isInspectorOpen or viewState.isAlwaysOnScreen then
            inspectTarget(getLookAtTarget())
        end
        if viewState.isLookupOpen then
            lookupTarget(viewState.lookupInput)
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

        viewStyle.buttonHeight = 21 * viewStyle.viewScale
    end
end

local function drawField(field, data)
    if type(field.validate) == 'function' then
        if not field.validate(data, field) then
            return
        end
    else
        if isEmpty(data[field.name]) then
            return
        end
    end

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

        if ImGui.BeginTabItem(' Watch ') then
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

        if ImGui.BeginTabItem(' Inspect ') then
            viewState.isInspectorOpen = true
            ImGui.Spacing()
            drawInspector()
            ImGui.EndTabItem()
        else
            viewState.isInspectorOpen = false
        end

        if ImGui.BeginTabItem(' Lookup ') then
            viewState.isLookupOpen = true
            ImGui.Spacing()
            ImGui.Text('Enter reference string or hash:')
            ImGui.SetNextItemWidth(viewStyle.windowWidth)
            viewState.lookupInput = ImGui.InputText('##Lookup', viewState.lookupInput, viewState.maxInputLen)
            if lookupResult.ready and not lookupResult.empty then
                ImGui.Spacing()
                for _, field in ipairs(inspectorObjectSchema) do
                    drawField(field, lookupResult)
                end
            else
                if lookupResult.ready then
                    ImGui.Spacing()
                    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.muted)
                    ImGui.TextWrapped('Nothing found.')
                    ImGui.PopStyleColor()
                end
                ImGui.Spacing()
            end
            ImGui.EndTabItem()
        else
            viewState.isLookupOpen = false
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

    if not viewState.isConsoleOpen and not viewState.isAlwaysOnScreen then
        return
    end

    initializeViewStyle()

    ImGui.SetNextWindowPos(viewStyle.windowX, viewStyle.windowY, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(viewStyle.windowWidth + viewStyle.windowPaddingX * 2 - 1, viewStyle.windowHeight)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, viewStyle.windowPaddingX, viewStyle.windowPaddingY)

    if viewState.isConsoleOpen then
        drawMainWindow()
    elseif viewState.isAlwaysOnScreen then
        drawInspectorWindow()
    end

    ImGui.PopStyleVar()
end)

registerForEvent('onUpdate', function(delta)
	Cron.Update(delta)
end)

registerHotkey('ToggleInspector', 'Toggle inspector window', function()
    if not viewState.isConsoleOpen then
        viewState.isAlwaysOnScreen = not viewState.isAlwaysOnScreen
    end
end)
