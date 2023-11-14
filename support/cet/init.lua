local Cron = require('Cron')
local Ref = require('Ref')

-- Utils --

local function isEmpty(value)
    return value == nil or value == 0 or value == '' or value == 'None'
end

local function isNotEmpty(value)
    return value ~= nil and value ~= 0 and value ~= '' and value ~= 'None'
end

-- App --

local isPluginFound = false
local isTweakXLFound = false

local cameraSystem
local targetingSystem
local spatialQuerySystem
local inspectionSystem

local function initializeEnvironment()
    isPluginFound = type(RedHotTools) == 'userdata'
    isTweakXLFound = type(TweakXL) == 'userdata'

    cameraSystem = Game.GetCameraSystem()
    targetingSystem = Game.GetTargetingSystem()
    spatialQuerySystem = Game.GetSpatialQueriesSystem()
    inspectionSystem = Game.GetInspectionSystem()
end

-- App :: Targeting --

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

-- App :: Resolving --

local function resolveComponents(entity)
    local components = {}

    for _, component in ipairs(inspectionSystem:GetComponents(entity)) do
        local data = {
            componentName = component:GetName().value,
            componentType = component:GetClassName().value,
            meshPath = '',
            morphPath = '',
            meshAppearance = '',
        }

        if component:IsA('entMeshComponent') or component:IsA('entSkinnedMeshComponent') then
            data.meshPath = inspectionSystem:ResolveResourcePath(component.mesh.hash)
            data.meshAppearance = component.meshAppearance.value

            if isEmpty(data.meshPath) then
                data.meshPath = ('%u'):format(component.mesh.hash)
            end
        end

        if component:IsA('entMorphTargetSkinnedMeshComponent') then
            data.morphPath = inspectionSystem:ResolveResourcePath(component.morphResource.hash)
            data.meshAppearance = component.meshAppearance.value

            if isEmpty(data.morphPath) then
                data.morphPath = ('%u'):format(component.morphResource.hash)
            end
        end

        local description = { data.componentType, data.componentName }
        data.description = table.concat(description, ' | ')

        data.hash = inspectionSystem:GetObjectHash(component)

        table.insert(components, data)
    end

    return components
end

local function fillTargetEntityData(target, data)
    if IsDefined(target.entity) then
        local entity = target.entity
        data.entity = entity
        data.entityID = entity:GetEntityID().hash
        data.entityType = entity:GetClassName().value

        local templatePath = inspectionSystem:GetTemplatePath(entity)
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

        data.components = resolveComponents(entity)
        data.hasComponents = (#data.components > 0)
    end

    data.isEntity = IsDefined(data.entity)
end

local function fillTargetNodeData(target, data)
    local sectorData
    if IsDefined(target.nodeInstance) then
        sectorData = inspectionSystem:ResolveSectorDataFromNodeInstance(target.nodeInstance)
    elseif isNotEmpty(target.nodeID) then
        sectorData = inspectionSystem:ResolveSectorDataFromNodeID(target.nodeID)
    end
    if sectorData and sectorData.sectorHash ~= 0 then
        data.sectorPath = inspectionSystem:ResolveResourcePath(sectorData.sectorHash)
        data.instanceIndex = sectorData.instanceIndex
        data.instanceCount = sectorData.instanceCount
        data.nodeIndex = sectorData.nodeIndex
        data.nodeCount = sectorData.nodeCount
        data.nodeID = sectorData.nodeID
        data.nodeType = sectorData.nodeType.value
    end

    if IsDefined(target.nodeDefinition) then
        local node = target.nodeDefinition
        data.nodeDefinition = target.nodeDefinition
        data.nodeType = inspectionSystem:GetTypeName(node).value

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
    end

    if isNotEmpty(data.nodeID) then
        data.nodeRef = inspectionSystem:ResolveNodeRefFromNodeHash(data.nodeID)
    elseif isNotEmpty(target.nodeID) then
        data.nodeRef = inspectionSystem:ResolveNodeRefFromNodeHash(target.nodeID)
    end

    data.isNode = IsDefined(data.nodeInstance) or IsDefined(data.nodeDefinition) or isNotEmpty(data.nodeID)
end

local function fillTargetDescription(_, data)
    if isNotEmpty(data.nodeType) then
        local description = { data.nodeType }
        if isNotEmpty(data.meshPath) then
            local resourceName = data.meshPath:match('\\([^\\]+)$')
            table.insert(description, resourceName)
        elseif isNotEmpty(data.materialPath) then
            local resourceName = data.materialPath:match('\\([^\\]+)$')
            table.insert(description, resourceName)
        elseif isNotEmpty(data.templatePath) then
            local resourceName = data.templatePath:match('\\([^\\]+)$')
            table.insert(description, resourceName)
        elseif isNotEmpty(data.nodeRef) then
            local nodeAlias = data.nodeRef:match('(#?[^/]+)$')
            table.insert(description, nodeAlias)
        elseif isNotEmpty(data.sectorPath) then
            local sectorName = data.sectorPath:match('\\([^\\.]+)%.')
            table.insert(description, sectorName)
            table.insert(description, data.nodeIndex)
        end
        data.description = table.concat(description, ' | ')
    elseif isNotEmpty(data.entityType) then
        data.description = ('%s | %d'):format(data.entityType, data.entityID)
    end
end

local function fillTargetHash(target, data)
    if isNotEmpty(target.hash) then
        data.hash = target.hash
    elseif IsDefined(target.nodeInstance) then
        data.hash = inspectionSystem:GetObjectHash(target.nodeInstance)
    elseif IsDefined(target.nodeDefinition) then
        data.hash = inspectionSystem:GetObjectHash(target.nodeDefinition)
    elseif IsDefined(target.entity) then
        data.hash = inspectionSystem:GetObjectHash(target.entity)
    end
end

local function expandTarget(target)
    if IsDefined(target.entity) and not IsDefined(target.nodeDefinition) then
        local entityID = target.entity:GetEntityID().hash
        local nodeID

        if entityID > 0xffffff then
            nodeID = entityID
        else
            local communityID = inspectionSystem:ResolveCommunityIDFromEntityID(entityID)
            if communityID.hash > 0xffffff then
                nodeID = communityID.hash
            end
        end

        if isNotEmpty(nodeID) then
            local streamingData = inspectionSystem:FindStreamedWorldNode(nodeID)
            target.nodeInstance = streamingData.nodeInstance
            target.nodeDefinition = streamingData.nodeDefinition
            target.nodeID = nodeID
        end
    end
end

local function resolveTargetData(target)
    expandTarget(target)
    local data = {}
    fillTargetEntityData(target, data)
    fillTargetNodeData(target, data)
    fillTargetDescription(target, data)
    fillTargetHash(target, data)
    return data
end

-- App :: Inspector --

local inspector = {
    target = nil,
    result = nil,
}

local function inspectTarget(target, collisionGroup, targetDistance)
    if not target or not target.resolved then
        inspector.target = nil
        inspector.result = nil
        return
    end

    if inspector.target then
        if inspector.target.hash == target.hash then
            inspector.result.targetDistance = targetDistance
            return
        end
    end

    local data = resolveTargetData(target)
    data.collisionGroup = collisionGroup.value
    data.targetDistance = targetDistance

    inspector.target = target
    inspector.result = data
end

local function initializeInspector()
    for _, collisionGroup in ipairs(collisionGroups) do
        collisionGroup.name = CName(collisionGroup.name)
    end
end

local function updateInspector()
    inspectTarget(getLookAtTarget())
end

-- App :: Lookup --

local lookup = {
    query = nil,
    result = nil,
    empty = true,
}

local function lookupTarget(lookupQuery)
    if isEmpty(lookupQuery) then
        lookup.query = nil
        lookup.result = nil
        return
    end

    if lookup.query == lookupQuery then
        return
    end

    local target = {}

    local lookupHash = lookupQuery:match('^(%d+)ULL$') or lookupQuery:match('^(%d+)$')
    if lookupHash ~= nil then
        local hash = loadstring('return ' .. lookupHash .. 'ULL', '')()
        target.resourceHash = hash

        local entity = Game.FindEntityByID(EntityID.new({ hash = hash }))
        if IsDefined(entity) then
            target.entity = entity
        else
            local streamingData = inspectionSystem:FindStreamedWorldNode(hash)
            if IsDefined(streamingData.nodeInstance) then
                target.nodeInstance = streamingData.nodeInstance
                target.nodeDefinition = streamingData.nodeDefinition
            else
                if hash <= 0xffffff then
                    local communityID = inspectionSystem:ResolveCommunityIDFromEntityID(hash)
                    if communityID.hash > 0xffffff then
                        streamingData = inspectionSystem:FindStreamedWorldNode(communityID.hash)
                        if IsDefined(streamingData.nodeInstance) then
                            target.nodeInstance = streamingData.nodeInstance
                            target.nodeDefinition = streamingData.nodeDefinition
                        else
                            target.nodeID = communityID.hash
                        end
                    end
                end
            end
        end
    else
        local resolvedRef = ResolveNodeRef(CreateEntityReference(lookupQuery, {}).reference, GlobalNodeID.GetRoot())
        if isNotEmpty(resolvedRef.hash) then
            local entity = Game.FindEntityByID(EntityID.new({ hash = resolvedRef.hash }))
            if IsDefined(entity) then
                target.entity = entity
            else
                local streamingData = inspectionSystem:FindStreamedWorldNode(resolvedRef.hash)
                target.nodeInstance = streamingData.nodeInstance
                target.nodeDefinition = streamingData.nodeDefinition
                target.nodeID = resolvedRef.hash
            end
        end
    end

    local data = resolveTargetData(target)

    if isNotEmpty(target.resourceHash) then
        data.resourcePath = inspectionSystem:ResolveResourcePath(target.resourceHash)
    end

    lookup.result = data
    lookup.empty = isEmpty(data.resourcePath) and isEmpty(data.entityID) and isEmpty(data.nodeID) and isEmpty(data.sectorPath)
    lookup.query = lookupQuery
end

local function updateLookup(lookupQuery)
    lookupTarget(lookupQuery)
end

-- App :: Scanner --

local scanner = {
    requested = false,
    results = {},
    filter = nil,
    filtered = {},
}

local function scanTargets(maxDistance)
    local player = GetPlayer()

	if not IsDefined(player) or IsDefined(GetMountedVehicle(player)) then
        return
	end

	if not maxDistance then
		maxDistance = 2.5
	end

	local position, _ = targetingSystem:GetCrosshairData(player)
    local results = {}

    for _, target in ipairs(inspectionSystem:GetStreamedWorldNodesInFrustum()) do
        --local hit = Vector4.NearestPointOnEdge(position, target.bounds.Min, target.bounds.Max)
        --local distance = Vector4.Distance(position, hit)
        local distance = Vector4.Distance(position, target.transform.position)
        if distance <= maxDistance then
            local data = resolveTargetData(target)
            data.description = ('%s @ %.2fm'):format(data.description, distance)
            data.targetDistance = distance
            data.worldPosition = target.transform.position
            table.insert(results, data)
        end
    end

    table.sort(results, function(a, b)
        return a.targetDistance < b.targetDistance
    end)

    scanner.results = results
    scanner.filter = nil
    scanner.filtered = results
    scanner.requested = true
end

local function updateScanner(filter)
    if isEmpty(filter) then
        scanner.filtered = scanner.results
        scanner.filter = nil
        return
    end

    local filtered = {}

	local filterEsc = filter:upper():gsub('([^%w])', '%%%1')
	local filterRe = filterEsc:gsub('%s+', '.* ') .. '.*'

    local fields = {
        'nodeType',
        'nodeRef',
        'sectorPath',
        'meshPath',
        'materialPath',
        'templatePath',
    }

    for _, result in ipairs(scanner.results) do
        for _, field in ipairs(fields) do
            if isNotEmpty(result[field]) then
                local value = result[field]:upper()
                if value:find(filterEsc) or value:find(filterRe) then
                    table.insert(filtered, result)
                    break
                end
            end
        end
    end

    scanner.filter = filter
    scanner.filtered = filtered
end

-- App :: Watcher --

local watcher = {
    targets = {},
    results = {},
    numTargets = 0,
}

local function watchTarget(entity)
    if not IsDefined(entity) then
        return
    end

    local key = tostring(entity:GetEntityID().hash)
    local target = { entity = Ref.Weak(entity) }

    watcher.targets[key] = target
    watcher.results[key] = resolveTargetData(target)
    watcher.numTargets = watcher.numTargets + 1
end

local function forgetTarget(entity)
    if not IsDefined(entity) then
        return
    end

    local key = tostring(entity:GetEntityID().hash)

    watcher.targets[key] = nil
    watcher.results[key] = nil
    watcher.numTargets = watcher.numTargets - 1

    collectgarbage()
end

local function initializeWatcher()
    watchTarget(GetPlayer())

    ObserveAfter('PlayerPuppet', 'OnGameAttached', function(this)
        watchTarget(this)
    end)

    ObserveAfter('PlayerPuppet', 'OnDetach', function(this)
        forgetTarget(this)
    end)

    ObserveBefore('gameuiPuppetPreviewGameController', 'OnPreviewInitialized', function(this)
        watchTarget(this:GetGamePuppet())
    end)

    ObserveBefore('gameuiPuppetPreviewGameController', 'OnUninitialize', function(this)
        if this:IsA('gameuiPuppetPreviewGameController') then
            forgetTarget(this:GetGamePuppet())
        end
    end)

    ObserveAfter('PhotoModePlayerEntityComponent', 'SetupInventory', function(this)
        watchTarget(this.fakePuppet)
    end)

    ObserveBefore('PhotoModePlayerEntityComponent', 'ClearInventory', function(this)
        forgetTarget(this.fakePuppet)
    end)
end

local function updateWatcher()
    for key, target in pairs(watcher.targets) do
        watcher.results[key] = resolveTargetData(target)
    end
end

-- GUI --

local viewState = {
    isConsoleOpen = false,
    isInspectorOpen = false,
    isLookupOpen = false,
    isWatcherOpen = false,
    isAlwaysOnScreen = false,
    scannerDistance = 2.5,
    scannerFilter = '',
    lookupQuery = '',
    maxInputLen = 256,
}

local viewStyle = {
    labelTextColor = 0xff9f9f9f,
    mutedTextColor = 0xff9f9f9f,
    dangerTextColor = 0xff6666ff,
    disabledButtonColor = 0xff4f4f4f,
}

local function initializeViewStyle()
    if not viewStyle.fontSize then
        viewStyle.fontSize = ImGui.GetFontSize()
        viewStyle.viewScale = viewStyle.fontSize / 13

        viewStyle.windowWidth = 400 * viewStyle.viewScale
        viewStyle.windowHeight = 0

        viewStyle.windowPaddingX = 8 * viewStyle.viewScale
        viewStyle.windowPaddingY = viewStyle.windowPaddingX

        viewStyle.windowX = GetDisplayResolution() - viewStyle.windowWidth - viewStyle.windowPaddingX * 2 - 5
        viewStyle.windowY = 5

        viewStyle.mainWindowFlags = ImGuiWindowFlags.NoResize
            + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse
        viewStyle.overlayWindowFlags = viewStyle.mainWindowFlags
            + ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoCollapse
            + ImGuiWindowFlags.NoInputs + ImGuiWindowFlags.NoNav
        viewStyle.projectionWindowFlags = ImGuiWindowFlags.NoSavedSettings
            + ImGuiWindowFlags.NoInputs + ImGuiWindowFlags.NoNav
            + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove
            + ImGuiWindowFlags.NoDecoration + ImGuiWindowFlags.NoBackground
            + ImGuiWindowFlags.NoFocusOnAppearing + ImGuiWindowFlags.NoBringToFrontOnFocus

        viewStyle.buttonHeight = 21 * viewStyle.viewScale

        viewStyle.scannerDistanceWidth = 110 * viewStyle.viewScale
        viewStyle.scannerFilterWidth = 170 * viewStyle.viewScale
        viewStyle.scannerStatsWidth = ImGui.CalcTextSize('000 / 000') * viewStyle.viewScale
    end
end

-- GUI :: Utils --

local function sanitizeTextInput(value)
    return value:gsub('`', '')
end

-- GUI :: Plugins --

local plugins = {}

local function registerPlugin(plugin)
    if type(plugin.getTargetActions) ~= 'function' then
        return false
    end

    table.insert(plugins, plugin)
    return true
end

local function getTargetActions(target, isInputMode)
    local actions = {}
    for _, plugin in ipairs(plugins) do
        local result = plugin.getTargetActions(target)
        if type(result) == 'table' then
            if #result == 0 then
                result = { result }
            end
            for _, action in ipairs(result) do
                if isNotEmpty(action.label) and type(action.callback) == 'function' then
                    if action.type == nil then
                        action.type = 'button'
                    end
                    if isInputMode or action.type ~= 'button' then
                        table.insert(actions, action)
                    end
                end
            end
        end
    end
    return actions
end

-- GUI :: Fieldsets --

local function formatDistance(data)
    return ('%.2fm'):format(data.targetDistance)
end

local function useInlineDistance(data)
    return isNotEmpty(data.collisionGroup) and '@'
end

local function isValidNodeIndex(data)
    return type(data.nodeIndex) == 'number' and data.nodeIndex >= 0
        and type(data.nodeCount) == 'number' and data.nodeCount > 0
end

local function isValidInstanceIndex(data)
    return isValidNodeIndex(data)
        and type(data.instanceIndex) == 'number' and data.instanceIndex >= 0
        and type(data.instanceCount) == 'number' and data.instanceCount > 0
        and (data.instanceIndex ~= data.nodeIndex or data.instanceCount ~= data.nodeCount)
end

local objectSchema = {
    {
        { name = 'collisionGroup', label = 'Collision:' },
        { name = 'targetDistance', label = 'Distance:', format = formatDistance, inline = useInlineDistance },
    },
    {
        { name = 'nodeType', label = 'Node Type:' },
        { name = 'nodeID', label = 'Node ID:', format = '%u' },
        { name = 'nodeRef', label = 'Node Ref:', wrap = true },
        { name = 'nodeIndex', label = 'Node Index:', format = '%d', validate = isValidNodeIndex },
        { name = 'nodeCount', label = '/', format = '%d', inline = true, validate = isValidNodeIndex },
        { name = 'instanceIndex', label = 'Node Instance:', format = '%d', validate = isValidInstanceIndex },
        { name = 'instanceCount', label = '/', format = '%d', inline = true, validate = isValidInstanceIndex },
        { name = 'sectorPath', label = 'World Sector:', wrap = true },
    },
    {
        { name = 'entityType', label = 'Entity Type:' },
        { name = 'entityID', label = 'Entity ID:', format = '%u' },
        { name = 'recordID', label = 'Record ID:' },
        { name = 'templatePath', label = 'Entity Template:', wrap = true },
        { name = 'appearanceName', label = 'Entity Appearance:' },
        { name = 'deviceClass', label = 'Device Class:' },
        { name = 'meshPath', label = 'Mesh Resource:', wrap = true },
        { name = 'meshAppearance', label = 'Mesh Appearance:' },
        { name = 'materialPath', label = 'Material:', wrap = true },
    },
    {
        { name = 'resourcePath', label = 'Resource:', wrap = true },
    }
}

local componentSchema = {
    { name = 'componentType', label = 'Component Type:' },
    { name = 'componentName', label = 'Component Name:' },
    { name = 'meshPath', label = 'Mesh Resource:', wrap = true },
    { name = 'morphPath', label = 'Morph Target:', wrap = true },
    { name = 'meshAppearance', label = 'Mesh Appearance:' },
}

local function isVisibleField(field, data)
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
    local label = field.label
    if field.inline then
        if type(field.inline) == 'function' then
            local inline = field.inline(data, field)
            if inline then
                ImGui.SameLine()
                if type(inline) == 'string' then
                    label = inline
                end
            end
        else
            ImGui.SameLine()
        end
    end

    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
    ImGui.Text(label)
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

local function drawComponents(components, maxComponents)
    if maxComponents == nil then
        maxComponents = 10
    end

    if maxComponents > 0 then
        local visibleComponents = maxComponents -- math.min(maxComponents, #components)
        ImGui.BeginChildFrame(1, 0, visibleComponents * ImGui.GetFrameHeightWithSpacing())
    end

    for _, componentData in ipairs(components) do
        local componentID = tostring(componentData.hash)
        if ImGui.TreeNodeEx(componentData.description .. '##' .. componentID, ImGuiTreeNodeFlags.SpanFullWidth) then
            for _, field in ipairs(componentSchema) do
                if isVisibleField(field, componentData) then
                    drawField(field, componentData)
                end
            end
            ImGui.TreePop()
        end
    end

    if maxComponents > 0 then
        ImGui.EndChildFrame()
    end
end

local function drawFieldset(targetData, withInputs, maxComponents, withSeparators)
    if withInputs == nil then
        withInputs = true
    end

    if maxComponents == nil then
        maxComponents = 10
    end

    if withSeparators == nil then
        withSeparators = true
    end

    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)

    local isFirstGroup = true
    for _, groupSchema in ipairs(objectSchema) do
        local isFirstField = true
        for _, field in ipairs(groupSchema) do
            if isVisibleField(field, targetData) then
                if isFirstField then
                    isFirstField = false
                    if isFirstGroup then
                        isFirstGroup = false
                    elseif withSeparators then
                        ImGui.Spacing()
                        ImGui.Separator()
                        ImGui.Spacing()
                    end
                end
                drawField(field, targetData)
            end
        end
    end

    if targetData.hasComponents and withInputs then
        if withSeparators then
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()
        end
        if ImGui.TreeNodeEx(('Components (%d)##Components'):format(#targetData.components), ImGuiTreeNodeFlags.SpanFullWidth) then
            drawComponents(targetData.components, maxComponents)
            ImGui.TreePop()
        end
        --ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
        --ImGui.Text(('Components (%d)'):format(#targetData.components))
        --ImGui.PopStyleColor()
    end

    ImGui.PopStyleColor()
    ImGui.PopStyleVar(2)

    local actions = getTargetActions(targetData, withInputs)
    if #actions > 0 then
        if withSeparators then
            ImGui.Spacing()
            ImGui.Separator()
        end
        ImGui.Spacing()
        for _, action in ipairs(actions) do
            if action.type == 'button' then
                if ImGui.Button(action.label) then
                    action.callback(targetData)
                end
            elseif action.type == 'checkbox' then
                local _, pressed = ImGui.Checkbox(action.label, action.state)
                if pressed then
                    action.callback(targetData)
                end
            end
        end
    end
end

-- GUI :: Projector --

local projectionQueue = {}

local function enqueueTargetProjection(target)
    table.insert(projectionQueue, target)
end

-- GUI :: Inspector --

local function drawInspectorContent(withInputs)
    if inspector.target and inspector.result then
        drawFieldset(inspector.result, withInputs)
    else
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
        ImGui.TextWrapped('No target.')
        ImGui.PopStyleColor()
    end
end

-- GUI :: Lookup --

local function drawLookupContent()
    ImGui.TextWrapped('Lookup world nodes and spawned entities by their identities.')
    ImGui.Spacing()
    ImGui.SetNextItemWidth(viewStyle.windowWidth)
    local query, queryChanged = ImGui.InputTextWithHint('##LookupQuery', 'Enter node reference or entity id or hash', viewState.lookupQuery, viewState.maxInputLen)
    if queryChanged then
        viewState.lookupQuery = sanitizeTextInput(query)
    end

    if lookup.result then
        if not lookup.empty then
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()
            drawFieldset(lookup.result)
        else
            ImGui.Spacing()
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
            ImGui.TextWrapped('Nothing found.')
            ImGui.PopStyleColor()
        end
    end
end

-- GUI :: Scanner --

local function drawScannerContent()
    ImGui.TextWrapped('Search for non-collision, hidden and unreachable world nodes.')
    ImGui.Spacing()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Scanning depth:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.scannerDistanceWidth)
    local distance, distanceChanged = ImGui.InputFloat('##ScannerDistance', viewState.scannerDistance, 0.5, 1.0, '%.1fm', ImGuiInputTextFlags.None)
    if distanceChanged then
        viewState.scannerDistance = math.max(1.0, math.min(50.0, distance))
    end
    ImGui.Spacing()

    if ImGui.Button('Scan world nodes', viewStyle.windowWidth, viewStyle.buttonHeight) then
        scanTargets(viewState.scannerDistance)
        updateScanner(viewState.scannerFilter)
    end

    if scanner.requested then
        ImGui.Spacing()
        if #scanner.results > 0 then
            ImGui.Separator()
            ImGui.Spacing()

            ImGui.AlignTextToFramePadding()
            ImGui.Text('Filter results:')
            ImGui.SameLine()
            ImGui.SetNextItemWidth(viewStyle.scannerFilterWidth)
            local filter, filterChanged = ImGui.InputTextWithHint('##ScannerFilter', 'Node type or reference or resource', viewState.scannerFilter, viewState.maxInputLen)
            if filterChanged then
                viewState.scannerFilter = sanitizeTextInput(filter)
                updateScanner(viewState.scannerFilter)
            end

            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
            ImGui.SetNextItemWidth(viewStyle.scannerStatsWidth)
            ImGui.Text(('%d / %d'):format(#scanner.filtered, #scanner.results))
            ImGui.PopStyleColor()
            ImGui.SameLine()
            local expandlAll = ImGui.Button('Expand all')
            ImGui.SameLine()
            local collapseAll = ImGui.Button('Collapse all')
            ImGui.Spacing()

            if #scanner.filtered > 0 then
                ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
                ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
                ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)

                local visibleRows = math.max(14, math.min(18, #scanner.filtered))
                ImGui.BeginChildFrame(1, 0, visibleRows * ImGui.GetFrameHeightWithSpacing())

                for _, result in ipairs(scanner.filtered) do
                    ImGui.BeginGroup()
                    if expandlAll then
                        ImGui.SetNextItemOpen(true)
                    elseif collapseAll then
                        ImGui.SetNextItemOpen(false)
                    end
                    local resultID = tostring(result.hash)
                    if ImGui.TreeNodeEx(result.description .. '##' .. resultID, ImGuiTreeNodeFlags.SpanFullWidth) then
                        ImGui.PopStyleColor()
                        ImGui.PopStyleVar()
                        drawFieldset(result, true, -1, false)
                        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
                        ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)
                        ImGui.TreePop()
                    end
                    ImGui.EndGroup()
                    if ImGui.IsItemHovered() then
                        enqueueTargetProjection(result)
                    end
                end

                ImGui.EndChildFrame()
                ImGui.PopStyleColor()
                ImGui.PopStyleVar(2)
            else
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
                ImGui.TextWrapped('No matches.')
                ImGui.PopStyleColor()
            end
        else
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
            ImGui.TextWrapped('Nothing found.')
            ImGui.PopStyleColor()
        end
    end
end

-- GUI :: Watcher --

local function drawWatcherContent()
    ImGui.TextWrapped('Watch all player related entities.')

    if watcher.numTargets > 0 then
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
        ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)

        local visibleRows = math.max(12, math.min(16, watcher.numTargets))
        ImGui.BeginChildFrame(1, 0, visibleRows * ImGui.GetFrameHeightWithSpacing())

        for _, result in pairs(watcher.results) do
            if ImGui.TreeNodeEx(result.description, ImGuiTreeNodeFlags.SpanFullWidth) then
                drawFieldset(result, true, 0, false)
                ImGui.TreePop()
            end
        end

        ImGui.EndChildFrame()
        ImGui.PopStyleColor()
        ImGui.PopStyleVar(2)
    else
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
        ImGui.TextWrapped('No entities to watch.')
        ImGui.PopStyleColor()
    end
end

-- GUI :: Windows --

local function getScreenDescriptor()
    local screen = {}
    screen.width, screen.height = GetDisplayResolution()
    screen.centerX = screen.width / 2
    screen.centerY = screen.height / 2

    return screen
end

local function drawProjectedPoint(screen, vertice, color, radius, thickness)
    local projected = cameraSystem:ProjectPoint(vertice)
    local pointX = screen.centerX + (projected.x * screen.centerX)
    local pointY = screen.centerY - (projected.y * screen.centerY)
    if thickness == true then
        ImGui.ImDrawListAddCircleFilled(ImGui.GetWindowDrawList(), pointX, pointY, radius, color, -1)
    else
        ImGui.ImDrawListAddCircle(ImGui.GetWindowDrawList(), pointX, pointY, radius, color, -1, thickness)
    end
end

local function drawProjections()
    if #projectionQueue == 0 then
        return
    end

    local screen = getScreenDescriptor()

    ImGui.SetNextWindowSize(screen.width, screen.height, ImGuiCond.Always)
    ImGui.SetNextWindowPos(0, 0, ImGuiCond.Always)

    if ImGui.Begin('Red Hot Tools Projection', true, viewStyle.projectionWindowFlags) then
        for _, target in ipairs(projectionQueue) do
            drawProjectedPoint(screen, target.worldPosition, 0xff00ff00, 8, 4)
        end
    end

    projectionQueue = {}
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
            ImGui.Spacing()

            --[[
            ImGui.Text('Archives')
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
            ImGui.TextWrapped(
                'Hot load archives from archive/pc/hot.\n' ..
                'New archives will be moved to archive/pc/mod and loaded.\n' ..
                'Existing archives will be unloaded and replaced.')
            ImGui.PopStyleColor()
            ImGui.Spacing()

            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.dangerTextColor)
            ImGui.Text('Not supported on game version 2.0+ yet')
            ImGui.PopStyleColor()
            ImGui.Spacing()

            --ImGui.Checkbox('Watch for changes', true)

            ImGui.PushStyleColor(ImGuiCol.Button, viewStyle.disabledButtonColor)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, viewStyle.disabledButtonColor)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, viewStyle.disabledButtonColor)
            if ImGui.Button('Reload archives', viewStyle.windowWidth, viewStyle.buttonHeight) then
                --RedHotTools.ReloadArchives()
            end
            ImGui.PopStyleColor(3)

            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()
            --]]

            ImGui.Text('Scripts')
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
            ImGui.TextWrapped('Hot load scripts from r6/scripts.')
            ImGui.PopStyleColor()
            ImGui.Spacing()

            if ImGui.Button('Reload scripts', viewStyle.windowWidth, viewStyle.buttonHeight) then
                RedHotTools.ReloadScripts()
            end

            if isTweakXLFound then
                ImGui.Spacing()
                ImGui.Separator()
                ImGui.Spacing()

                ImGui.Text('Tweaks')
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
                ImGui.TextWrapped('Hot load tweaks from r6/tweaks and scriptable tweaks.')
                ImGui.PopStyleColor()
                ImGui.Spacing()

                if ImGui.Button('Reload tweaks', viewStyle.windowWidth, viewStyle.buttonHeight) then
                    RedHotTools.ReloadTweaks()
                end
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

        if ImGui.BeginTabItem(' Scan ') then
            ImGui.Spacing()
            drawScannerContent()
            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem(' Lookup ') then
            viewState.isLookupOpen = true
            ImGui.Spacing()
            drawLookupContent()
            ImGui.EndTabItem()
        else
            viewState.isLookupOpen = false
        end

        if ImGui.BeginTabItem(' Watch ') then
            viewState.isWatcherOpen = true
            ImGui.Spacing()
            drawWatcherContent()
            ImGui.EndTabItem()
        else
            viewState.isWatcherOpen = false
        end
    end
    ImGui.End()
end

-- GUI :: Events --

registerForEvent('onOverlayOpen', function()
    viewState.isConsoleOpen = true
end)

registerForEvent('onOverlayClose', function()
    viewState.isConsoleOpen = false
    viewState.isInspectorOpen = false
    viewState.isLookupOpen = false
    viewState.isWatcherOpen = false
end)

registerForEvent('onDraw', function()
    if not isPluginFound then
        return
    end

    if not viewState.isConsoleOpen and not viewState.isAlwaysOnScreen then
        return
    end

    initializeViewStyle()
    drawProjections()

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

-- Bindings --

registerHotkey('ToggleInspector', 'Toggle inspector window', function()
    if not viewState.isConsoleOpen then
        viewState.isAlwaysOnScreen = not viewState.isAlwaysOnScreen
    end
end)

-- Main --

registerForEvent('onInit', function()
    initializeEnvironment()

    if isPluginFound then
        initializeInspector()
        initializeWatcher()

        Cron.Every(0.2, function()
            if viewState.isInspectorOpen or viewState.isAlwaysOnScreen then
                updateInspector()
            end
            if viewState.isLookupOpen then
                updateLookup(viewState.lookupQuery)
            end
            if viewState.isWatcherOpen then
                updateWatcher()
            end
        end)
    end
end)

registerForEvent('onUpdate', function(delta)
	Cron.Update(delta)
end)

-- API --

return {
    RegisterPlugin = registerPlugin,
    GetLookAtObject = getLookAtTarget,
    CollectTargetData = resolveTargetData,
    GetInspectorTarget = function()
        return inspector.result
    end,
    GetScannerTargets = function()
        return scanner.results
    end,
    GetLookupTarget = function()
        return lookup.result
    end,
}
