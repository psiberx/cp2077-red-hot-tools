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
    {
        { name = 'targetDistance', label = 'Distance:',
            format = function(data)
                return ('%.2fm'):format(data.targetDistance)
            end
        },
        { name = 'collisionGroup', label = 'Collision Group:' },
    },
    {
        { name = 'nodeType', label = 'Node Type:' },
        { name = 'nodeID', label = 'Node ID:', format = '%u' },
        { name = 'nodeRef', label = 'Node Ref:', wrap = true },
        { name = 'nodeIndex', label = 'Node Index:', format = '%d',
            validate = function(data)
                return type(data.nodeIndex) == 'number' and data.nodeIndex > 0
            end,
    --         format = function(data)
    --             return ('%d / %d'):format(data.nodeIndex, data.nodeCount)
    --         end
        },
        { name = 'nodeCount', label = '/', format = '%d', inline = true },
        { name = 'sectorPath', label = 'World Sector:', wrap = true },
    },
    {
        { name = 'meshPath', label = 'Mesh Resource:', wrap = true },
        { name = 'meshAppearance', label = 'Mesh Appearance:' },
        { name = 'materialPath', label = 'Material Resource:', wrap = true },
        { name = 'deviceClass', label = 'Device Class:' },
    },
    {
        { name = 'entityType', label = 'Entity Type:' },
        { name = 'entityID', label = 'Entity ID:', format = '%u' },
        { name = 'recordID', label = 'Record ID:' },
        { name = 'templatePath', label = 'Entity Template:', wrap = true },
        { name = 'appearanceName', label = 'Entity Appearance:' },
    },
    {
        { name = 'resourcePath', label = 'Resource:', wrap = true },
    }
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

local function collectTargetData(target)
    local data = {}

    if IsDefined(target.entity) then
        local entity = target.entity
        data.entityID = entity:GetEntityID().hash
        data.entityType = entity:GetClassName().value

        local templatePath = entity:GetTemplatePath().resource
        data.templatePath = inspectionSystem:ResolveResourcePath(templatePath.hash)
        data.appearanceName = entity:GetCurrentAppearanceName().value
        if isEmpty(data.templatePath) and isNotEmpty(templatePath.hash) then
            data.templatePath = ('%u'):format(templatePath.hash)
        end

        if entity:IsA('gameObject') then
            local recordID = entity:GetTDBID()
            if TDBID.IsValid(recordID) then
                data.recordID = TDBID.ToStringDEBUG(recordID)
            end
        end

        data.components = collectComponents(entity)
        data.hasComponents = (#data.components > 0)

        if not IsDefined(target.node) then
            if data.entityID > 0xffffff then
                target.nodeID = data.entityID
            else
                local communityID = inspectionSystem:ResolveCommunityIDFromEntityID(data.entityID)
                if communityID.hash > 0xffffff then
                    target.nodeID = communityID.hash
                end
            end

            if isNotEmpty(target.nodeID) then
                target.node = inspectionSystem:FindWorldNode(data.nodeID)
            end
        end
    end

    if IsDefined(target.node) then
        local node = target.node
        data.nodeType = inspectionSystem:GetTypeName(node).value

        local nodeData = inspectionSystem:ResolveNodeDataFromNode(node)
        if nodeData.sectorHash ~= 0 then
            data.sectorPath = inspectionSystem:ResolveResourcePath(nodeData.sectorHash)
            data.nodeIndex = nodeData.nodeIndex
            data.nodeCount = nodeData.nodeCount
            data.nodeID = nodeData.nodeID
        end

        if inspectionSystem:IsInstanceOf(node, 'worldMeshNode') or inspectionSystem:IsInstanceOf(node, 'worldInstancedMeshNode') then
            data.meshPath = inspectionSystem:ResolveResourcePath(node.mesh.hash)
            data.meshAppearance = node.meshAppearance.value
        end

        if inspectionSystem:IsInstanceOf(node, 'worldStaticDecalNode') then
            data.materialPath = inspectionSystem:ResolveResourcePath(node.material.hash)
        end

        if inspectionSystem:IsInstanceOf(node, 'worldEntityNode') then
            data.templatePath = inspectionSystem:ResolveResourcePath(node.entityTemplate.hash)
            data.appearanceName = node.appearanceName.value
        end

        if inspectionSystem:IsInstanceOf(node, 'worldDeviceNode') then
            data.deviceClass = node.deviceClassName.value
        end
    elseif isNotEmpty(target.nodeID) then
        local nodeData = inspectionSystem:ResolveNodeDataFromNodeID(target.nodeID)
        if nodeData.sectorHash ~= 0 then
            data.sectorPath = inspectionSystem:ResolveResourcePath(nodeData.sectorHash)
            data.nodeIndex = nodeData.nodeIndex
            data.nodeCount = nodeData.nodeCount
            data.nodeID = nodeData.nodeID
            data.nodeType = nodeData.nodeType.value
        end
    end

    if isNotEmpty(data.nodeID) then
        data.nodeRef = inspectionSystem:ResolveNodeRefFromNodeHash(data.nodeID)
    end

    return data
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

    local data = collectTargetData(target)
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

    local target = {}

    local lookupHash = lookupInput:match('^(%d+)ULL$') or lookupInput:match('^(%d+)$')
    if lookupHash ~= nil then
        local hash = loadstring('return ' .. lookupHash .. 'ULL', '')()
        target.resourceHash = hash

        local entity = Game.FindEntityByID(EntityID.new({ hash = hash }))
        if IsDefined(entity) then
            target.entity = entity
        else
            local node = inspectionSystem:FindWorldNode(hash)
            if IsDefined(node) then
                target.node = node
            else
                if hash <= 0xffffff then
                    local communityID = inspectionSystem:ResolveCommunityIDFromEntityID(hash)
                    if communityID.hash > 0xffffff then
                        hash = communityID.hash
                        node = inspectionSystem:FindWorldNode(hash)
                        if IsDefined(node) then
                            --data = collectTargetData({ node = node })
                            target.node = node
                        else
                            target.nodeID = hash
                        end
                    end
                end
            end
        end
    else
        local resolvedRef = ResolveNodeRef(CreateEntityReference(lookupInput, {}).reference, GlobalNodeID.GetRoot())
        if isNotEmpty(resolvedRef.hash) then
            target.nodeID = resolvedRef.hash
        end
    end

    local data = collectTargetData(target)

    if isNotEmpty(target.resourceHash) then
        data.resourcePath = inspectionSystem:ResolveResourcePath(target.resourceHash)
    end

    data.empty = isEmpty(data.resourcePath) and isEmpty(data.entityID) and isEmpty(data.nodeID) and isEmpty(data.sectorPath)
    data.input = lookupInput
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

local function canDrawField(field, data)
    if type(field.validate) == 'function' then
        if not field.validate(data, field) then
            return false
        end
    else
        if isEmpty(data[field.name]) then
            return false
        end
    end
    return true
end

local function drawField(field, data)
    if field.inline then
        ImGui.SameLine()
    end

    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.label)
    ImGui.Text(field.label)
    ImGui.PopStyleColor()

    local value = data[field.name]
    if field.format then
        if type(field.format) == 'function' then
            value = field.format(data, field)
        elseif type(field.format) == 'string' then
            value = (field.format):format(value)
        end
    else
        value = tostring(value)
    end

    ImGui.SameLine()
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
                if canDrawField(field, componentData) then
                    drawField(field, componentData)
                end
            end
            ImGui.TreePop()
        end
    end
    ImGui.EndChildFrame()
end

local function drawInspectorFieldset(targetData, withComponents)
    if withComponents == nil then
        withComponents = true
    end

    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)

    local isFirstGroup = true
    for _, groupSchema in ipairs(inspectorObjectSchema) do
        local isFirstField = true
        for _, field in ipairs(groupSchema) do
            if canDrawField(field, targetData) then
                if isFirstField then
                    isFirstField = false
                    if isFirstGroup then
                        isFirstGroup = false
                    else
                        ImGui.Separator()
                    end
                end
                drawField(field, targetData)
            end
        end
    end

    if targetData.hasComponents then
--         ImGui.Separator()
        if withComponents then
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.label)
            ImGui.Text('Components:')
            ImGui.PopStyleColor()
            drawComponentsTree(targetData.components, 10)
        else
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.label)
            ImGui.Text(('Components (%d)'):format(#targetData.components))
            ImGui.PopStyleColor()
        end
    end

    ImGui.PopStyleColor()
    ImGui.PopStyleVar(2)
end

local function drawInspectorContent(withComponents)
    if inspecting then
        drawInspectorFieldset(inspectorData, withComponents)
    else
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.muted)
        ImGui.TextWrapped('No target.')
        ImGui.PopStyleColor()
    end
end

local function drawLookupContent()
    ImGui.Text('Enter reference string or hash:')
    ImGui.SetNextItemWidth(viewStyle.windowWidth)
    viewState.lookupInput = ImGui.InputText('##Lookup', viewState.lookupInput, viewState.maxInputLen)

    if lookupResult.ready and not lookupResult.empty then
        ImGui.Spacing()
        drawInspectorFieldset(lookupResult)
    else
        if lookupResult.ready then
            ImGui.Spacing()
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.muted)
            ImGui.TextWrapped('Nothing found.')
            ImGui.PopStyleColor()
        end
    end
end

local function drawInspectorWindow()
    ImGui.Begin('Red Hot Tools', viewStyle.overlayWindowFlags)
    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - 2)
    drawInspectorContent(false)
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
            drawInspectorContent(true)
            ImGui.EndTabItem()
        else
            viewState.isInspectorOpen = false
        end

        if ImGui.BeginTabItem(' Lookup ') then
            viewState.isLookupOpen = true
            ImGui.Spacing()
            drawLookupContent()
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
    viewState.isInspectorOpen = false
    viewState.isLookupOpen = false
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
