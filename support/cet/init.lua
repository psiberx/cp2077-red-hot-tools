local Cron = require('Cron')
local Ref = require('Ref')
local PersistentState = require('PersistentState')

-- Utils --

local function isEmpty(value)
    return value == nil or value == 0 or value == '' or value == 'None'
end

local function isNotEmpty(value)
    return value ~= nil and value ~= 0 and value ~= '' and value ~= 'None'
end

local function clamp(value, rangeMin, rangeMax)
    return math.max(rangeMin, math.min(rangeMax, value))
end

local function opacity(abgr)
    return bit32.band(bit32.rshift(abgr, 24), 0xFF)
end

local function fade(abgr, a)
    return bit32.bor(bit32.lshift(bit32.band(a, 0xFF), 24), bit32.band(abgr, 0xFFFFFF))
end

local function insideBox(point, box)
    return point.x >= box.Min.x and point.y >= box.Min.y and point.z >= box.Min.z
        and point.x <= box.Max.x and point.y <= box.Max.y and point.z <= box.Max.z
end

local function enum(...)
    local map = { values = {} }
    for index, value in ipairs({...}) do
        map[value] = value
        map.values[index] = value
        map.values[value] = index
    end
    return map
end

-- App --

local isPluginFound = false
local isArchiveXLFound = false
local isTweakXLFound = false

local cameraSystem
local targetingSystem
local spatialQuerySystem
local inspectionSystem

local function initializeEnvironment()
    isPluginFound = type(RedHotTools) == 'userdata'
    isArchiveXLFound = type(ArchiveXL) == 'userdata'
    isTweakXLFound = type(TweakXL) == 'userdata'

    cameraSystem = Game.GetCameraSystem()
    targetingSystem = Game.GetTargetingSystem()
    spatialQuerySystem = Game.GetSpatialQueriesSystem()

    if isPluginFound then
        inspectionSystem = Game.GetInspectionSystem()
    end
end

-- App :: User State --

local Feature = enum('None', 'Inspect', 'Scan', 'Lookup', 'Watch', 'Reload')
local TargetingMode = enum('GamePhysics', 'StaticBounds')
local ColorScheme = enum('Green', 'Red', 'Yellow', 'White', 'Shimmer')
local OutlineMode = enum('ForSupportedObjects', 'Never')
local MarkerMode = enum('Always', 'ForStaticMeshes', 'WhenOutlineIsUnsupported', 'Never')
local BoundingBoxMode = enum('ForAreaNodes', 'Never')
local WindowSnapping = enum('Disabled', 'TopLeft', 'TopRight')

local userState = {}
local userStateSchema = {
    windowSnapping = { type = WindowSnapping, default = WindowSnapping.Disabled },
    activeTool = { type = Feature, default = Feature.Inspect },
    showOnScreenDisplay = { type = 'boolean', default = false },
    scannerFilter = { type = 'string', default = '' },
    scannerGroup = { type = 'string', default = '' },
    scannerDistance = { type = 'number', default = 25.0 },
    highlightColor = { type = ColorScheme, default = ColorScheme.Red },
    outlineMode = { type = OutlineMode, default = OutlineMode.ForSupportedObjects },
    markerMode = { type = MarkerMode, default = MarkerMode.ForStaticMeshes },
    boundingBoxMode = { type = BoundingBoxMode, default = BoundingBoxMode.Never },
    showMarkerDistance = { type = 'boolean', default = true },
    showBoundingBoxDistances = { type = 'boolean', default = false },
    targetingMode = { type = TargetingMode, default = TargetingMode.GamePhysics },
    maxTargets = { type = 'number', default = 8 },
    highlightInspectorResult = { type = 'boolean', default = true },
    highlightScannerResult = { type = 'boolean', default = true },
    highlightLookupResult = { type = 'boolean', default = false },
    keepLastHoveredResultHighlighted = { type = 'boolean', default = true },
}

local function initializeUserState()
    PersistentState.Initialize('.state', userState, userStateSchema)
end

local function saveUserState()
    PersistentState.Flush()
end

-- App :: Targeting --

local collisionGroups = {
    { name = 'Static', threshold = 0.0, tolerance = 0.2 },
    { name = 'Dynamic', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'Cloth', threshold = 0.2, tolerance = 0.0 },
    --{ name = 'Player', threshold = 0.2, tolerance = 0.0 },
    --{ name = 'AI', threshold = 0.0, tolerance = 0.0 },
    { name = 'Vehicle', threshold = 0.0, tolerance = 0.0 },
    --{ name = 'Tank', threshold = 0.0, tolerance = 0.0 },
    { name = 'Destructible', threshold = 0.0, tolerance = 0.0 },
    { name = 'Terrain', threshold = 0.0, tolerance = 0.0 },
    { name = 'Collider', threshold = 0.0, tolerance = 0.0 },
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

local extendedCollisionGroups = {
    { name = 'Static+' },
    { name = 'Dynamic+' },
}

local frustumMaxDistance = 100

local function initializeTargeting()
    frustumMaxDistance = inspectionSystem:GetFrustumMaxDistance()

    for _, collision in ipairs(collisionGroups) do
        collision.name = StringToName(collision.name)
    end

    for _, collision in ipairs(extendedCollisionGroups) do
        collision.name = StringToName(collision.name)
    end
end

local function getCameraData(distance)
	local player = GetPlayer()

	if not IsDefined(player) or IsDefined(GetMountedVehicle(player)) then
        return nil
	end

    local position, forward = targetingSystem:GetCrosshairData(player)
    local destination = position

    if distance ~= nil then
        destination = Vector4.new(
            position.x + forward.x * distance,
            position.y + forward.y * distance,
            position.z + forward.z * distance,
            position.w
        )
    end

    return {
        position = position,
        forward = forward,
        destination = destination,
        instigator = Ref.Weak(player)
    }
end

local function getLookAtTargets(maxDistance)
	local camera = getCameraData(maxDistance or frustumMaxDistance)

	if not camera then
        return
	end

	if userState.targetingMode == TargetingMode.GamePhysics then
        local results = {}

        local entity = targetingSystem:GetLookAtObject(camera.instigator, true, false)
        if IsDefined(entity) then
            table.insert(results, {
                resolved = true,
                entity = Ref.Weak(entity),
                hash = inspectionSystem:GetObjectHash(entity),
                distance = Vector4.Distance(camera.position, ToVector4(entity:GetWorldPosition())),
                collision = extendedCollisionGroups[2],
            })
        end

        for _, collision in ipairs(collisionGroups) do
            local success, trace = spatialQuerySystem:SyncRaycastByCollisionGroup(camera.position, camera.destination, collision.name, false, false)
            if success then
                local target = inspectionSystem:GetPhysicsTraceObject(trace)
                if target.resolved then
                    local distance = Vector4.Distance(camera.position, ToVector4(trace.position))
                    if distance > collision.threshold then
                        target.distance = distance
                        target.collision = collision
                        table.insert(results, target)
                    end
                end
            end
        end

        if #results == 0 then
            return
        end

        local nearest = results[1]

        for i = 2, #results do
            local diff = nearest.distance - results[i].distance
            if diff > results[i].collision.tolerance then
                nearest = results[i]
            end
        end

        return { nearest }
	end

    if userState.targetingMode == TargetingMode.StaticBounds then
        local results = inspectionSystem:GetStreamedWorldNodesInCrosshair()

        if #results == 0 then
            return
        end

        while #results > userState.maxTargets do
            table.remove(results)
        end

        return results
    end
end

-- App :: Highlighting --

local highlight = {
    target = nil,
    pending = nil,
    projections = {},
    color = 0,
    outline = 0,
}

local shimmer = {
    steps = { 1, 5, 3, 4 },
    reverse = false,
    state = 1,
    tick = 1,
    delay = 1,
}

local colorMapping = {
    [ColorScheme.Green] = 0xFF32FF1D,
    [ColorScheme.Red] = 0xFF050FFF,
    [ColorScheme.Yellow] = 0xFF62E8FC,
    [ColorScheme.White] = 0xFFFFFFFF,
    [ColorScheme.Shimmer] = 0xFF0060FF,
}

local outlineMapping = {
    [ColorScheme.Green] = 1,
    [ColorScheme.Red] = 2,
    [ColorScheme.Yellow] = 5,
    [ColorScheme.White] = 7,
    [ColorScheme.Shimmer] = 0,
}

local function initializeHighlighting()
    highlight.color = colorMapping[userState.highlightColor]
    highlight.outline = outlineMapping[userState.highlightColor]

    if userState.highlightColor == ColorScheme.Shimmer then
        shimmer.state = 1
        shimmer.reverse = false
        highlight.outline = shimmer.steps[shimmer.state]
    end
end

local function applyHighlightEffect(target, enabled)
    local effect = entRenderHighlightEvent.new({
        seeThroughWalls = true,
        outlineIndex = enabled and highlight.outline or 0,
        opacity = 1.0
    })

    if IsDefined(target.entity) then
        return inspectionSystem:ApplyHighlightEffect(target.entity, effect)
    end

    if IsDefined(target.parentInstance) then
        return inspectionSystem:ApplyHighlightEffect(target.parentInstance, effect)
    end

    if IsDefined(target.nodeInstance) then
        return inspectionSystem:ApplyHighlightEffect(target.nodeInstance, effect)
    end

    return false
end

local function enableHighlight(target)
    local isOutlineActive = false
    if userState.outlineMode == OutlineMode.ForSupportedObjects then
        isOutlineActive = applyHighlightEffect(target, true)

        if isOutlineActive and userState.highlightColor == ColorScheme.Shimmer then
            if shimmer.tick == shimmer.delay then
                if shimmer.reverse then
                    shimmer.state = shimmer.state - 1
                    if shimmer.state == 1 then
                        shimmer.reverse = false
                    end
                else
                    shimmer.state = shimmer.state + 1
                    if shimmer.state == #shimmer.steps then
                        shimmer.reverse = true
                    end
                end
                shimmer.tick = 1
            else
                shimmer.tick = shimmer.tick + 1
            end

            highlight.outline = shimmer.steps[shimmer.state]
        end
    end

    highlight.projections = {}

    local showMarker = false
    if not target.isCollisionNode then
        if userState.markerMode == MarkerMode.Always then
            showMarker = true
        elseif userState.markerMode == MarkerMode.ForStaticMeshes and userState.targetingMode == TargetingMode.StaticBounds then
            showMarker = true
        elseif userState.markerMode == MarkerMode.WhenOutlineIsUnsupported and (not isOutlineActive or target.isProxyMeshNode) then
            showMarker = true
        end
    end

    local showBoundindBox = false
    if not target.isCollisionNode then
        if userState.boundingBoxMode == BoundingBoxMode.ForAreaNodes and target.isAreaNode then
            showBoundindBox = true
        end
    end

    if showMarker or showBoundindBox then
        highlight.projections[target.hash] = {
            target = target,
            color = highlight.color,
            showMarker = showMarker,
            showBoundindBox = showBoundindBox,
        }
    end
end

local function disableHighlight(target)
    applyHighlightEffect(target, false)
    highlight.projections = {}
end

local function highlightTarget(target)
    if target and target.hash then
        highlight.pending = target
    else
        highlight.pending = nil
    end
end

local function disableHighlights()
    if highlight.target then
        disableHighlight(highlight.target)
        highlight.target = nil
    end
end

local function updateHighlights()
    if not highlight.pending then
        disableHighlights()
        return
    end

    if highlight.target then
        if highlight.target.hash ~= highlight.pending.hash then
            disableHighlights()
        end
    end

    highlight.target = highlight.pending
    highlight.pending = nil

    enableHighlight(highlight.target)
end

-- App :: Resolving --

local nodeGroupMapping = {
    ['gameCyberspaceBoundaryNode'] = 'Boundaries',
    ['gameDynamicEventNode'] = 'Maps',
    ['gameEffectTriggerNode'] = 'Effects',
    ['gameKillTriggerNode'] = 'Boundaries',
    ['gameWorldBoundaryNode'] = 'Boundaries',
    ['MinimapDataNode'] = 'Maps',
    ['worldAcousticPortalNode'] = 'Audio',
    ['worldAcousticSectorNode'] = 'Audio',
    ['worldAcousticsOutdoornessAreaNode'] = 'Audio',
    ['worldAcousticZoneNode'] = 'Audio',
    ['worldAdvertisementNode'] = 'Meshes',
    ['worldAIDirectorSpawnAreaNode'] = 'AI',
    ['worldAIDirectorSpawnNode'] = 'AI',
    ['worldAISpotNode'] = 'AI',
    ['worldAmbientAreaNode'] = 'Audio',
    ['worldAmbientPaletteExclusionAreaNode'] = 'Audio',
    ['worldAreaProxyMeshNode'] = 'Other',
    ['worldAreaShapeNode'] = 'Other',
    ['worldAudioAttractAreaNode'] = 'Scene',
    ['worldAudioSignpostTriggerNode'] = 'Audio',
    ['worldAudioTagNode'] = 'Audio',
    ['worldBakedDestructionNode'] = 'Meshes',
    ['worldBendedMeshNode'] = 'Meshes',
    ['worldBuildingProxyMeshNode'] = 'Meshes',
    ['worldCableMeshNode'] = 'Meshes',
    ['worldClothMeshNode'] = 'Meshes',
    ['worldCollisionAreaNode'] = 'Collisions',
    ['worldCollisionNode'] = 'Collisions',
    ['worldCommunityRegistryNode'] = 'Population',
    ['worldCompiledCommunityAreaNode'] = 'Population',
    ['worldCompiledCommunityAreaNode_Streamable'] = 'Population',
    ['worldCompiledCrowdParkingSpaceNode'] = 'Population',
    ['worldCompiledSmartObjectsNode'] = 'AI',
    ['worldCrowdNullAreaNode'] = 'Population',
    ['worldCrowdParkingSpaceNode'] = 'Population',
    ['worldCrowdPortalNode'] = 'Population',
    ['worldCurvePathNode'] = 'Other',
    ['worldDecorationMeshNode'] = 'Meshes',
    ['worldDecorationProxyMeshNode'] = 'Meshes',
    ['worldDestructibleEntityProxyMeshNode'] = 'Meshes',
    ['worldDestructibleProxyMeshNode'] = 'Meshes',
    ['worldDeviceNode'] = 'Entities',
    ['worldDistantGINode'] = 'Lighting',
    ['worldDistantLightsNode'] = 'Lighting',
    ['worldDynamicMeshNode'] = 'Meshes',
    ['worldEffectNode'] = 'Effects',
    ['worldEntityNode'] = 'Entities',
    ['worldEntityProxyMeshNode'] = 'Entities',
    ['worldFoliageDestructionNode'] = 'Meshes',
    ['worldFoliageNode'] = 'Meshes',
    ['worldGenericProxyMeshNode'] = 'Meshes',
    ['worldGeometryShapeNode'] = 'Other',
    ['worldGINode'] = 'Lighting',
    ['worldGIShapeNode'] = 'Lighting',
    ['worldGISpaceNode'] = 'Lighting',
    ['worldGuardAreaNode'] = 'AI',
    ['worldInstancedDestructibleMeshNode'] = 'Meshes',
    ['worldInstancedMeshNode'] = 'Meshes',
    ['worldInstancedOccluderNode'] = 'Culling',
    ['worldInterestingConversationsAreaNode'] = 'Scene',
    ['worldInteriorAreaNode'] = 'Areas',
    ['worldInteriorMapNode'] = 'Maps',
    ['worldInvalidProxyMeshNode'] = 'Meshes',
    ['worldLightChannelShapeNode'] = 'Lighting',
    ['worldLightChannelVolumeNode'] = 'Lighting',
    ['worldLocationAreaNode'] = 'Maps',
    ['worldMeshNode'] = 'Meshes',
    ['worldMinimapConfigAreaNode'] = 'Maps',
    ['worldMinimapModeOverrideAreaNode'] = 'Maps',
    ['worldMirrorNode'] = 'Culling',
    ['worldNavigationConfigAreaNode'] = 'Navigation',
    ['worldNavigationDeniedAreaNode'] = 'Navigation',
    ['worldNavigationNode'] = 'Navigation',
    ['worldOffMeshConnectionNode'] = 'Navigation',
    ['worldOffMeshSmartObjectNode'] = 'Navigation',
    ['worldPatrolSplineNode'] = 'Navigation',
    ['worldPerformanceAreaNode'] = 'Other',
    ['worldPhysicalDestructionNode'] = 'Meshes',
    ['worldPhysicalFractureFieldNode'] = 'Physics',
    ['worldPhysicalImpulseAreaNode'] = 'Physics',
    ['worldPhysicalTriggerAreaNode'] = 'Physics',
    ['worldPopulationSpawnerNode'] = 'Population',
    ['worldPrefabNode'] = 'Other',
    ['worldPrefabProxyMeshNode'] = 'Meshes',
    ['worldPreventionFreeAreaNode'] = 'Areas',
    ['worldQuestProxyMeshNode'] = 'Meshes',
    ['worldRaceSplineNode'] = 'Navigation',
    ['worldReflectionProbeNode'] = 'Lighting',
    ['worldRoadProxyMeshNode'] = 'Meshes',
    ['worldRotatingMeshNode'] = 'Meshes',
    ['worldSaveSanitizationForbiddenAreaNode'] = 'Areas',
    ['worldSceneRecordingContentObserverNode'] = 'Other',
    ['worldSmartObjectNode'] = 'AI',
    ['worldSocketNode'] = 'Other',
    ['worldSpeedSplineNode'] = 'Navigation',
    ['worldSplineNode'] = 'Other',
    ['worldStaticDecalNode'] = 'Meshes',
    ['worldStaticFogVolumeNode'] = 'Lighting',
    ['worldStaticGpsLocationEntranceMarkerNode'] = 'Maps',
    ['worldStaticLightNode'] = 'Lighting',
    ['worldStaticMarkerNode'] = 'Maps',
    ['worldStaticMeshNode'] = 'Meshes',
    ['worldStaticOccluderMeshNode'] = 'Culling',
    ['worldStaticParticleNode'] = 'Particles',
    ['worldStaticQuestMarkerNode'] = 'Maps',
    ['worldStaticSoundEmitterNode'] = 'Audio',
    ['worldStaticStickerNode'] = 'Other',
    ['worldStaticVectorFieldNode'] = 'Particles',
    ['worldTerrainCollisionNode'] = 'Collisions',
    ['worldTerrainMeshNode'] = 'Terrain',
    ['worldTerrainProxyMeshNode'] = 'Terrain',
    ['worldTrafficCollisionGroupNode'] = 'Navigation',
    ['worldTrafficCompiledNode'] = 'Navigation',
    ['worldTrafficPersistentNode'] = 'Navigation',
    ['worldTrafficSourceNode'] = 'Navigation',
    ['worldTrafficSplineNode'] = 'Navigation',
    ['worldTrafficSpotNode'] = 'Navigation',
    ['worldTriggerAreaNode'] = 'Areas',
    ['worldVehicleForbiddenAreaNode'] = 'Areas',
    ['worldWaterNullAreaNode'] = 'Water',
    ['worldWaterPatchNode'] = 'Water',
    ['worldWaterPatchProxyMeshNode'] = 'Water',
}

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

    data.entity = target.entity
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
        data.nodeType = sectorData.nodeType.value
        data.nodeID = sectorData.nodeID
        data.parentID = sectorData.parentID
    end

    if IsDefined(target.nodeDefinition) then
        local node = target.nodeDefinition
        data.nodeType = inspectionSystem:GetTypeName(node).value

        if inspectionSystem:IsInstanceOf(node, 'worldMeshNode')
        or inspectionSystem:IsInstanceOf(node, 'worldInstancedMeshNode')
        or inspectionSystem:IsInstanceOf(node, 'worldBendedMeshNode')
        or inspectionSystem:IsInstanceOf(node, 'worldFoliageNode')
        or inspectionSystem:IsInstanceOf(node, 'worldPhysicalDestructionNode') then
            data.meshPath = inspectionSystem:ResolveResourcePath(node.mesh.hash)
            data.meshAppearance = node.meshAppearance.value
        end

        if inspectionSystem:IsInstanceOf(node, 'worldTerrainMeshNode') then
            data.meshPath = inspectionSystem:ResolveResourcePath(node.meshRef.hash)
        end

        if inspectionSystem:IsInstanceOf(node, 'worldStaticDecalNode') then
            data.materialPath = inspectionSystem:ResolveResourcePath(node.material.hash)
        end

        if inspectionSystem:IsInstanceOf(node, 'worldEffectNode') then
            data.effectPath = inspectionSystem:ResolveResourcePath(node.effect.hash)
        end

        if inspectionSystem:IsInstanceOf(node, 'worldPopulationSpawnerNode') then
            data.recordID = node.objectRecordId.value
            data.appearanceName = node.appearanceName.value
        end

        if inspectionSystem:IsInstanceOf(node, 'worldEntityNode') then
            data.templatePath = inspectionSystem:ResolveResourcePath(node.entityTemplate.hash)
            data.appearanceName = node.appearanceName.value
        end

        if inspectionSystem:IsInstanceOf(node, 'worldDeviceNode') then
            data.deviceClass = node.deviceClassName.value
        end

        if inspectionSystem:IsInstanceOf(node, 'worldTriggerAreaNode') then
            data.triggerNotifiers = {}
            for _, notifier in ipairs(node.notifiers) do
                table.insert(data.triggerNotifiers, inspectionSystem:GetTypeName(notifier).value)
            end
        end
    end

    if isNotEmpty(data.nodeID) then
        data.nodeRef = inspectionSystem:ResolveNodeRefFromNodeHash(data.nodeID)
    elseif isNotEmpty(target.nodeID) then
        data.nodeRef = inspectionSystem:ResolveNodeRefFromNodeHash(target.nodeID)
    end

    if isNotEmpty(data.parentID) then
        data.parentRef = inspectionSystem:ResolveNodeRefFromNodeHash(data.parentID)
        if isNotEmpty(data.parentRef) then
            data.parentInstance = inspectionSystem:FindStreamedWorldNode(data.parentID).nodeInstance
        end
    end

    data.nodeDefinition = target.nodeDefinition
    data.nodeInstance = target.nodeInstance

    data.isNode = IsDefined(data.nodeInstance) or IsDefined(data.nodeDefinition) or isNotEmpty(data.nodeID)
    data.isAreaNode = data.isNode and inspectionSystem:IsInstanceOf(data.nodeDefinition, 'worldAreaShapeNode')
    data.isProxyMeshNode = data.isNode and inspectionSystem:IsInstanceOf(data.nodeDefinition, 'worldPrefabProxyMeshNode')
    data.isCommunityNode = data.isNode and inspectionSystem:IsInstanceOf(data.nodeDefinition, 'worldCompiledCommunityAreaNode')
    data.isSpawnerNode = data.isNode and inspectionSystem:IsInstanceOf(data.nodeDefinition, 'worldPopulationSpawnerNode')
    data.isVisibleNode = data.isNode and (isNotEmpty(data.meshPath) or isNotEmpty(data.materialPath) or isNotEmpty(data.templatePath))
        or inspectionSystem:IsInstanceOf(data.nodeDefinition, 'worldStaticLightNode')
    data.isCollisionNode = data.isNode and inspectionSystem:IsInstanceOf(data.nodeDefinition, 'worldCollisionNode')

    if isNotEmpty(data.nodeType) then
        data.nodeGroup = nodeGroupMapping[data.nodeType]
    end
end

local function fillTargetGeomertyData(target, data)
    data.collision = target.collision
    data.distance = target.distance
    data.position = target.position

    if target.boundingBox and not target.boundingBox.Min:IsXYZZero() and target.boundingBox.Min.x <= target.boundingBox.Max.x then
        data.boundingBox = target.boundingBox
        data.position = Game['OperatorAdd;Vector4Vector4;Vector4'](data.boundingBox.Min, data.boundingBox:GetExtents())
    end

    if not data.position then
        if IsDefined(data.entity) then
            data.position = data.entity:GetWorldPosition()
        elseif IsDefined(data.nodeInstance) then
            local position = inspectionSystem:GetStreamedNodePosition(data.nodeInstance)
            if not position:IsXYZZero() then
                data.position = position
            end
        end
    end
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
        elseif isNotEmpty(data.effectPath) then
            local resourceName = data.effectPath:match('\\([^\\]+)$')
            table.insert(description, resourceName)
        elseif isNotEmpty(data.templatePath) then
            local resourceName = data.templatePath:match('\\([^\\]+)$')
            table.insert(description, resourceName)
        elseif isNotEmpty(data.nodeRef) then
            local nodeAlias = data.nodeRef:match('(#?[^/]+)$')
            table.insert(description, nodeAlias)
        elseif isNotEmpty(data.recordID) then
            table.insert(description, data.recordID)
        elseif isNotEmpty(data.sectorPath) then
            local sectorName = data.sectorPath:match('\\([^\\.]+)%.')
            table.insert(description, sectorName)
            table.insert(description, data.nodeIndex)
        end
        data.description = table.concat(description, ' | ')
    elseif isNotEmpty(data.entityType) then
        data.description = ('%s | %d'):format(data.entityType, data.entityID)
    end

    --if isNotEmpty(data.description) and data.distance then
    --    data.description = ('%s @ %.2fm'):format(data.description, data.distance)
    --end

     --if isNotEmpty(data.nodeType) then
     --    local subs = {
     --        '^world',
     --        '^Compiled',
     --        '^Instanced',
     --        '^Generic',
     --        '^Static',
     --        '_Streamable$',
     --        'Node$',
     --        'Proxy',
     --    }
     --
     --    local nodeTypeAlias = data.nodeType
     --    for _, sub in ipairs(subs) do
     --        nodeTypeAlias = nodeTypeAlias:gsub(sub, '')
     --    end
     --
     --    data.nodeTypeAlias = nodeTypeAlias
     --end
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

        if entityID > 0xFFFFFF then
            nodeID = entityID
        else
            local communityID = inspectionSystem:ResolveCommunityIDFromEntityID(entityID)
            if communityID.hash > 0xFFFFFF then
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

    local result = {}
    fillTargetEntityData(target, result)
    fillTargetNodeData(target, result)
    fillTargetGeomertyData(target, result)
    fillTargetDescription(target, result)
    fillTargetHash(target, result)

    return result
end

-- App :: Nodes --

local lastTarget

local function canToggleNodeState(target)
    return target and IsDefined(target.nodeInstance) and target.isVisibleNode
end

local function toggleNodeState(target)
    if not target or not canToggleNodeState(target) then
        target = lastTarget
        lastTarget = nil
    end

    if target then
        if IsDefined(target.parentInstance) then
            inspectionSystem:ToggleNodeVisibility(target.parentInstance)
            lastTarget = target
        elseif IsDefined(target.nodeInstance) then
            inspectionSystem:ToggleNodeVisibility(target.nodeInstance)
            lastTarget = target
        end
    end
end

-- App :: Inspector --

local inspector = {
    targets = nil,
    results = nil,
    active = nil,
}

local function isSameTargets(setA, setB)
    if #setA ~= #setB then
        return false
    end

    local size = #setA
    local hashesA = {}
    local hashesB = {}

    for i = 1,size do
        table.insert(hashesA, setA[i].hash)
        table.insert(hashesB, setB[i].hash)
    end

    table.sort(hashesA)
    table.sort(hashesB)

    for i = 1,size do
        if hashesA[i] ~= hashesB[i] then
            return false
        end
    end

    return true
end

local function updateDistances(results, targets)
    for _, target in ipairs(targets) do
        for _, result in ipairs(results) do
            if result.hash == target.hash then
                result.distance = target.distance
                break
            end
        end
    end
end

local function inspectTargets(targets)
    if not targets or #targets == 0 then
        inspector.targets = {}
        inspector.results = {}
        inspector.active = nil
        return
    end

    if inspector.targets then
        if isSameTargets(inspector.targets, targets) then
            updateDistances(inspector.results, targets)
            return
        end
    end

    local results = {}
    for _, target in ipairs(targets) do
        local result = resolveTargetData(target)
        if result then
            table.insert(results, result)
        end
    end

    local active = 1
    if inspector.active and #inspector.results > 1 then
         for index, result in ipairs(results) do
             if result.hash == inspector.results[inspector.active].hash then
                active = index
                break
             end
         end
    end

    inspector.targets = targets
    inspector.results = results
    inspector.active = active
end

local function selectInspectedResult(index)
    inspector.active = index
    if inspector.active < 1 then
        inspector.active = 1
    elseif inspector.active > #inspector.results then
        inspector.active = #inspector.results
    end
end

local function cycleNextInspectedResult()
    if inspector.active then
        inspector.active = inspector.active + 1
        if inspector.active > #inspector.results then
            inspector.active = 1
        end
    end
end

local function cyclePrevInspectedResult()
    if inspector.active then
        inspector.active = inspector.active - 1
        if inspector.active < 1 then
            inspector.active = #inspector.results
        end
    end
end

local function updateInspector()
    inspectTargets(getLookAtTargets())

    if userState.highlightInspectorResult and inspector.active then
        highlightTarget(inspector.results[inspector.active])
    end
end

-- App :: Scanner --

local scanner = {
    requested = false,
    finished = false,
    results = {},
    distance = 0,
    group = '',
    term = nil,
    filtered = {},
    hovered = nil,
}

local function requestScan()
    scanner.requested = true
end

local function selectScannedResult(index)
    scanner.hovered = index
end

local function unselectScannedResult()
    scanner.hovered = nil
end

local function scanTargets()
    if not scanner.requested then
        return
    end

    scanner.requested = false

    local results = {}

    for _, target in ipairs(inspectionSystem:GetStreamedWorldNodesInFrustum()) do
        local result = resolveTargetData(target)
        if result then
            table.insert(results, result)
        end
    end

    table.sort(results, function(a, b)
        return a.distance < b.distance
    end)

    for index, result in ipairs(results) do
        result.index = index
    end

    scanner.results = results
    scanner.term = nil
    scanner.filtered = results
    scanner.hovered = nil
    scanner.finished = true
end

local function filterTargetByDistance(target, distance)
    return isEmpty(distance) or target.distance <= distance
end

local function filterTargetByGroup(target, group)
    return isEmpty(group) or target.nodeGroup == group
end

local partialMatchFields = {
    'nodeType',
    'nodeRef',
    'parentRef',
    'sectorPath',
    'meshPath',
    'materialPath',
    'effectPath',
    'templatePath',
    'recordID',
    'triggerNotifiers',
}

local exactMatchFields = {
    'instanceIndex',
}

local function buildQuery(term)
    if isEmpty(term) then
        return nil
    end

    local exact = term:upper()
    local escaped = exact:gsub('([^%w])', '%%%1')
    local wildcard = escaped:gsub('%s+', '.* ') .. '.*'

    return {
        exact = exact,
        escaped = escaped,
        wildcard = wildcard,
    }
end

local function filterTargetByQuery(target, query)
    if isEmpty(query) then
        return true
    end

    for _, field in ipairs(exactMatchFields) do
        if isNotEmpty(target[field]) then
            local value = tostring(target[field]):upper()
            if value == query.exact then
                return true
            end
        end
    end

    for _, field in ipairs(partialMatchFields) do
        if type(target[field]) == 'table' then
            for _, item in ipairs(target[field]) do
                local value = tostring(item):upper()
                if value:find(query.escaped) or value:find(query.wildcard) then
                    return true
                end
            end
        elseif isNotEmpty(target[field]) then
            local value = tostring(target[field]):upper()
            if value:find(query.escaped) or value:find(query.wildcard) then
                return true
            end
        end
    end

    return false
end

local function filterTargets(maxDistance, group, term)
    if scanner.group == group and scanner.term == term and scanner.distance == maxDistance then
        return
    end

    local filtered = {}
    local query = buildQuery(term)

    for _, result in ipairs(scanner.results) do
        if filterTargetByDistance(result, maxDistance)
        and filterTargetByGroup(result, group)
        and filterTargetByQuery(result, query) then
            table.insert(filtered, result)
        end
    end

    scanner.distance = maxDistance
    scanner.group = group
    scanner.term = term
    scanner.filtered = filtered
end

local function updateScanner(distance, group, filter)
    scanTargets()
    filterTargets(distance, group, filter)

    if userState.highlightScannerResult and scanner.hovered then
        highlightTarget(scanner.results[scanner.hovered])
    end
end

-- App :: Lookup --

local lookup = {
    query = nil,
    result = nil,
    empty = true,
}

local function parseLookupHash(lookupQuery)
    local lookupHex = lookupQuery:match('^0x([0-9A-F]+)$')
    if lookupHex ~= nil then
        return loadstring('return 0x' .. lookupHex .. 'ULL', '')()
    end

    local lookupDec = lookupQuery:match('^(%d+)ULL$') or lookupQuery:match('^(%d+)$')
    if lookupDec ~= nil then
        return loadstring('return ' .. lookupDec .. 'ULL', '')()
    end

    return nil
end

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

    local lookupHash = parseLookupHash(lookupQuery)
    if lookupHash ~= nil then
        target.resourceHash = lookupHash
        target.tdbidHash = lookupHash
        target.nameHash = lookupHash

        local entity = Game.FindEntityByID(EntityID.new({ hash = lookupHash }))
        if IsDefined(entity) then
            target.entity = entity
        else
            local streamingData = inspectionSystem:FindStreamedWorldNode(lookupHash)
            if IsDefined(streamingData.nodeInstance) then
                target.nodeInstance = streamingData.nodeInstance
                target.nodeDefinition = streamingData.nodeDefinition
            else
                if lookupHash <= 0xFFFFFF then
                    local communityID = inspectionSystem:ResolveCommunityIDFromEntityID(lookupHash)
                    if communityID.hash > 0xFFFFFF then
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

    local data = resolveTargetData(target) or {}

    if isNotEmpty(target.resourceHash) then
        data.resolvedPath = inspectionSystem:ResolveResourcePath(target.resourceHash)
    end

    if isNotEmpty(target.tdbidHash) then
		local length = math.floor(tonumber(target.tdbidHash / 0x100000000))
		local hash = tonumber(target.tdbidHash - (length * 0x100000000))
        local name = ToTweakDBID{ hash = hash, length = length }.value
        if name and not name:match('^<') then
            data.resolvedTDBID = name
        end
    end

    if isNotEmpty(target.nameHash) then
        local hi = tonumber(bit32.rshift(target.nameHash, 32))
        local lo = tonumber(bit32.band(target.nameHash, 0xFFFFFFFF))
        data.resolvedName = ToCName{ hash_hi = hi, hash_lo = lo }.value
    end

    lookup.result = data
    lookup.empty = isEmpty(data.entityID) and isEmpty(data.nodeID) and isEmpty(data.sectorPath)
        and isEmpty(data.resourcePath) and isEmpty(data.resolvedTDBID) and isEmpty(data.resolvedName)
    lookup.query = lookupQuery
end

local function updateLookup(lookupQuery)
    lookupTarget(lookupQuery)

    if userState.highlightLookupResult then
        highlightTarget(lookup.result)
    end
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
    isFirstOpen = true,
    isConsoleOpen = false,
    isWindowOpen = true,
    scannerFilter = '',
    lookupQuery = '',
}

local viewData = {
    maxInputLen = 512,
}

local viewStyle = {
    labelTextColor = 0xFF9F9F9F, --0xFFA5A19B
    mutedTextColor = 0xFFA5A19B,
    hintTextColor = 0x66FFFFFF,
    dangerTextColor = 0xFF6666FF,
    disabledButtonColor = 0xFF4F4F4F,
}

local function buildComboOptions(values, capitalize)
    local options = {}
    for index, value in ipairs(values) do
        options[index] = value:gsub('([a-z])([A-Z])', function(l, u)
            return l .. ' ' .. (capitalize and u or u:lower())
        end)
    end
    return options
end

local function buildMappingOptions(mapping, first)
    local options = {}
    for _, group in pairs(mapping) do
        if not options[group] then
            table.insert(options, group)
            options[group] = group
        end
    end

    table.sort(options)
    table.insert(options, 1, first)

    for index, group in ipairs(options) do
        options[group] = index
    end

    options[''] = 1

    return options
end

local function initializeViewData()
    viewData.targetingModeOptions = buildComboOptions(TargetingMode.values, true)
    viewData.colorSchemeOptions = buildComboOptions(ColorScheme.values)
    viewData.outlineModeOptions = buildComboOptions(OutlineMode.values)
    viewData.markerModeOptions = buildComboOptions(MarkerMode.values)
    viewData.boundingBoxModeOptions = buildComboOptions(BoundingBoxMode.values)
    viewData.windowSnappingOptions = buildComboOptions(WindowSnapping.values, true)
    viewData.nodeGroupOptions = buildMappingOptions(nodeGroupMapping, 'All')
end

local function initializeViewStyle()
    if not viewStyle.fontSize then
        viewStyle.fontSize = ImGui.GetFontSize()
        viewStyle.viewScale = viewStyle.fontSize / 13

        viewStyle.windowPaddingX = 8 * viewStyle.viewScale
        viewStyle.windowPaddingY = viewStyle.windowPaddingX

        viewStyle.windowWidth = 400 * viewStyle.viewScale
        viewStyle.windowFullWidth = viewStyle.windowWidth + viewStyle.windowPaddingX * 2 - 1
        viewStyle.windowHeight = 0

        viewStyle.windowTopY = 4
        viewStyle.windowLeftX = 4
        viewStyle.windowRightX = GetDisplayResolution() - viewStyle.windowFullWidth - 4

        viewStyle.mainWindowFlags = ImGuiWindowFlags.NoResize
            + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse
        viewStyle.inspectorWindowFlags = viewStyle.mainWindowFlags
            + ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoCollapse
            + ImGuiWindowFlags.NoInputs + ImGuiWindowFlags.NoNav
        viewStyle.projectionWindowFlags = ImGuiWindowFlags.NoSavedSettings
            + ImGuiWindowFlags.NoInputs + ImGuiWindowFlags.NoNav
            + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove
            + ImGuiWindowFlags.NoDecoration + ImGuiWindowFlags.NoBackground
            + ImGuiWindowFlags.NoFocusOnAppearing + ImGuiWindowFlags.NoBringToFrontOnFocus

        viewStyle.buttonHeight = 21 * viewStyle.viewScale

        viewStyle.scannerFilterWidth = 95 * viewStyle.viewScale
        viewStyle.scannerGroupWidth = 75 * viewStyle.viewScale
        viewStyle.scannerDistanceWidth = 85 * viewStyle.viewScale
        viewStyle.scannerStatsWidth = ImGui.CalcTextSize('0000 / 0000') * viewStyle.viewScale

        viewStyle.settingsShortInputWidth = 80 * viewStyle.viewScale
        viewStyle.settingsMiddleInputWidth = 90 * viewStyle.viewScale
        viewStyle.settingsShortComboRowWidth = 160 * viewStyle.viewScale
        viewStyle.settingsMiddleComboRowWidth = 210 * viewStyle.viewScale
        viewStyle.settingsLongComboRowWidth = 240 * viewStyle.viewScale
    end
end

-- GUI :: Utils --

local function sanitizeTextInput(value)
    return value:gsub('`', '')
end

-- GUI :: Extensions --

local extensions = {}

local function registerExtension(plugin)
    if type(plugin.getTargetActions) ~= 'function' then
        return false
    end

    table.insert(extensions, plugin)
    return true
end

-- GUI :: Actions --

local function getToggleNodeActionName()
    return 'Toggle node visibility'
end

local function getTargetActions(target, isInputMode)
    local actions = {}

    if isInputMode then
        if canToggleNodeState(target) then
            table.insert(actions, {
                type = 'button',
                label = getToggleNodeActionName(target),
                callback = toggleNodeState,
            })
        end
    end

    for _, plugin in ipairs(extensions) do
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

local function formatArrayField(data, field)
    return table.concat(data[field.name], '\n')
end

local function formatDistance(data)
    return ('%.2fm'):format(type(data) == 'table' and data.distance or data)
end

local function isValidInstanceIndex(data)
    return type(data.instanceIndex) == 'number' and data.instanceIndex >= 0
        and type(data.instanceCount) == 'number' and data.instanceCount > 0
end

local resultSchema = {
    {
        { name = 'nodeType', label = 'Node Type:' },
        { name = 'nodeID', label = 'Node ID:', format = '%u' },
        { name = 'nodeRef', label = 'Node Ref:', wrap = true },
        { name = 'parentRef', label = 'Parent Ref:', wrap = true },
        --{ name = 'nodeIndex', label = 'Node Index:', format = '%d', validate = isValidNodeIndex },
        --{ name = 'nodeCount', label = '/', format = '%d', inline = true, validate = isValidNodeIndex },
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
        { name = 'effectPath', label = 'Effect:', wrap = true },
        { name = 'triggerNotifiers', label = 'Trigger Notifiers:', format = formatArrayField },
    },
    {
        { name = 'resolvedPath', label = 'Resource:', wrap = true },
        { name = 'resolvedName', label = 'CName:' },
        { name = 'resolvedTDBID', label = 'TweakDBID:' },
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
        local visibleComponents = maxComponents
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
    for _, groupSchema in ipairs(resultSchema) do
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
                if action.inline then
                    ImGui.SameLine()
                end
                if ImGui.Button(action.label) then
                    action.callback(targetData)
                end
            elseif action.type == 'checkbox' then
                if action.inline then
                    ImGui.SameLine()
                end
                local _, pressed = ImGui.Checkbox(action.label, action.state)
                if pressed then
                    action.callback(targetData)
                end
            end
        end
    end
end

-- GUI :: Inspector --

local function drawInspectorContent(isModal)
    ImGui.Text(viewData.targetingModeOptions[TargetingMode.values[userState.targetingMode]])
    if inspector.active then
        if inspector.results[inspector.active].collision then
            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
            ImGui.Text('/')
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.Text(inspector.results[inspector.active].collision.name.value)
        end
        if inspector.results[inspector.active].distance then
            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
            ImGui.Text('@')
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.Text(formatDistance(inspector.results[inspector.active].distance))
        end
        if #inspector.results > 1 then
            ImGui.Spacing()
            ImGui.BeginGroup()
            for index = 1,#inspector.results do
                local isActive = (index == inspector.active)
                ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 0)
                if not isActive then
                    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 1)
                    ImGui.PushStyleColor(ImGuiCol.Button, 0)
                end
                --local label = ('%d %s'):format(index, inspector.results[index].nodeTypeAlias)
                local label = (' %d '):format(index)
                if ImGui.Button(label) then
                    selectInspectedResult(index)
                end
                if not isActive then
                    ImGui.PopStyleVar()
                    ImGui.PopStyleColor()
                end
                ImGui.PopStyleVar()
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip(inspector.results[index].nodeType)
                end
                ImGui.SameLine()
            end
            ImGui.EndGroup()

        end
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()
        drawFieldset(inspector.results[inspector.active], not isModal)
    else
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
        ImGui.Text('@')
        ImGui.SameLine()
        ImGui.Text('No target')
        ImGui.PopStyleColor()
    end
end

-- GUI :: Scanner --

local function drawScannerContent()
    ImGui.TextWrapped('Search for non-collision, hidden and unreachable world nodes.')
    ImGui.Spacing()

    if ImGui.Button('Scan world nodes', viewStyle.windowWidth, viewStyle.buttonHeight) then
        requestScan()
    end

    if scanner.finished then
        if not userState.keepLastHoveredResultHighlighted then
            unselectScannedResult()
        end

        ImGui.Spacing()
        if #scanner.results > 0 then
            ImGui.Separator()
            ImGui.Spacing()

            --ImGui.SameLine()
            ImGui.AlignTextToFramePadding()
            ImGui.Text('Group:')
            ImGui.SameLine()
            ImGui.SetNextItemWidth(viewStyle.scannerGroupWidth)
            local groupIndex, groupChanged = ImGui.Combo('##ScannerGroup', viewData.nodeGroupOptions[userState.scannerGroup] - 1, viewData.nodeGroupOptions, #viewData.nodeGroupOptions)
            if groupChanged then
                userState.scannerGroup = groupIndex ~= 0 and viewData.nodeGroupOptions[groupIndex + 1] or ''
            end

            ImGui.SameLine()
            ImGui.AlignTextToFramePadding()
            ImGui.Text('Filter:')
            ImGui.SameLine()
            ImGui.SetNextItemWidth(viewStyle.scannerFilterWidth)
            ImGui.PushStyleColor(ImGuiCol.TextDisabled, viewStyle.hintTextColor)
            local filter, filterChanged = ImGui.InputTextWithHint('##ScannerFilter', '', userState.scannerFilter, viewData.maxInputLen)
            if filterChanged then
                userState.scannerFilter = sanitizeTextInput(filter)
            end
            ImGui.PopStyleColor()
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 4, 0)
            local isEmptyFilter = isEmpty(userState.scannerFilter)
            if isEmptyFilter then
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.hintTextColor)
            end
            ImGui.SameLine()
            if ImGui.Button(' x ') then
                userState.scannerFilter = ''
            end
            if isEmptyFilter then
                ImGui.PopStyleColor()
            end
            ImGui.PopStyleVar()

            ImGui.SameLine()
            ImGui.AlignTextToFramePadding()
            ImGui.Text('Distance:')
            ImGui.SameLine()
            ImGui.SetNextItemWidth(viewStyle.windowWidth + viewStyle.windowPaddingX - ImGui.GetCursorPosX())
            local distance, distanceChanged = ImGui.InputFloat('##ScannerDistance', userState.scannerDistance, 0.5, 1.0, '%.1fm', ImGuiInputTextFlags.None)
            if distanceChanged then
                userState.scannerDistance = clamp(distance, 0.5, frustumMaxDistance)
            end

            ImGui.Spacing()

            --ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
            ImGui.AlignTextToFramePadding()
            ImGui.Text('Showing:')
            ImGui.SameLine()
            ImGui.Text(('%d / %d'):format(#scanner.filtered, #scanner.results))
            --ImGui.PopStyleColor()
            ImGui.SameLine()
            local expandlAll = ImGui.Button('Expand all')
            ImGui.SameLine()
            local collapseAll = ImGui.Button('Collapse all')

            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()

            if #scanner.filtered > 0 then
                ImGui.PushStyleVar(ImGuiStyleVar.IndentSpacing, 0)
                ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
                ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
                ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)

                local visibleRows = clamp(#scanner.filtered, 14, 18)
                ImGui.BeginChildFrame(1, 0, visibleRows * ImGui.GetFrameHeightWithSpacing())

                for _, result in ipairs(scanner.filtered) do
                    ImGui.BeginGroup()
                    if expandlAll then
                        ImGui.SetNextItemOpen(true)
                    elseif collapseAll then
                        ImGui.SetNextItemOpen(false)
                    end
                    local resultID = tostring(result.hash)
                    local nodeFlags = ImGuiTreeNodeFlags.SpanFullWidth
                    if userState.keepLastHoveredResultHighlighted then
                        if result.index == scanner.hovered then
                            nodeFlags = nodeFlags + ImGuiTreeNodeFlags.Selected
                        end
                    end
                    if ImGui.TreeNodeEx(result.description .. '##' .. resultID, nodeFlags) then
                        ImGui.PopStyleColor()
                        ImGui.PopStyleVar()
                        drawFieldset(result, true, -1, false)
                        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
                        ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)
                        ImGui.TreePop()
                    end
                    ImGui.EndGroup()
                    if ImGui.IsItemHovered() then
                        selectScannedResult(result.index)
                    end
                end

                ImGui.EndChildFrame()
                ImGui.PopStyleColor()
                ImGui.PopStyleVar(3)
            else
                ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
                ImGui.TextWrapped('No matches')
                ImGui.PopStyleColor()
            end
        else
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
            ImGui.TextWrapped('Nothing found')
            ImGui.PopStyleColor()
        end
    end
end

-- GUI :: Lookup --

local function drawLookupContent()
    ImGui.TextWrapped('Lookup world nodes and spawned entities by their identities.')
    ImGui.Spacing()
    ImGui.SetNextItemWidth(viewStyle.windowWidth)
    ImGui.PushStyleColor(ImGuiCol.TextDisabled, viewStyle.hintTextColor)
    local query, queryChanged = ImGui.InputTextWithHint('##LookupQuery', 'Enter node reference or entity id or hash', viewState.lookupQuery, viewData.maxInputLen)
    if queryChanged then
        viewState.lookupQuery = sanitizeTextInput(query)
    end
    ImGui.PopStyleColor()

    if lookup.result then
        if not lookup.empty then
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()
            drawFieldset(lookup.result)
        else
            ImGui.Spacing()
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
            ImGui.TextWrapped('Nothing found')
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

        local visibleRows = clamp(watcher.numTargets, 14, 18)
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
        ImGui.TextWrapped('No entities to watch')
        ImGui.PopStyleColor()
    end
end

-- GUI :: Hot Reload --

local function drawHotReloadContent()
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

    if isArchiveXLFound then
        ImGui.Text('Archives')
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
        ImGui.TextWrapped('Hot load extensions from archive/pc/mod and mods/*/archives.')
        ImGui.PopStyleColor()
        ImGui.Spacing()

        if ImGui.Button('Reload extensions', viewStyle.windowWidth, viewStyle.buttonHeight) then
            ArchiveXL.Reload()
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()
    end

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
            TweakXL.Reload()
        end
    end
end

-- GUI :: Settings --

local function drawSettingsContent()
    local state, changed

    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.SetWindowFontScale(0.85)
    ImGui.Text('WINDOW')
    ImGui.SetWindowFontScale(1.0)
    ImGui.PopStyleColor()
    ImGui.Separator()
    ImGui.Spacing()

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
    ImGui.Spacing()
    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.SetWindowFontScale(0.85)
    ImGui.Text('HIGHLIGHTING')
    ImGui.SetWindowFontScale(1.0)
    ImGui.PopStyleColor()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Color theme:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsShortComboRowWidth - ImGui.GetCursorPosX())
    state, changed = ImGui.Combo('##HighlightColor', ColorScheme.values[userState.highlightColor] - 1, viewData.colorSchemeOptions, #viewData.colorSchemeOptions)
    if changed then
        userState.highlightColor = ColorScheme.values[state + 1]
        initializeHighlighting()
    end
    ImGui.EndGroup()

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Show outline:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsLongComboRowWidth - ImGui.GetCursorPosX())
    state, changed = ImGui.Combo('##OutlineMode', OutlineMode.values[userState.outlineMode] - 1, viewData.outlineModeOptions, #viewData.outlineModeOptions)
    if changed then
        userState.outlineMode = OutlineMode.values[state + 1]
    end
    ImGui.EndGroup()

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Show marker:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsLongComboRowWidth - ImGui.GetCursorPosX())
    state, changed = ImGui.Combo('##MarkerMode', MarkerMode.values[userState.markerMode] - 1, viewData.markerModeOptions, #viewData.markerModeOptions)
    if changed then
        userState.markerMode = MarkerMode.values[state + 1]
    end
    ImGui.EndGroup()
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(
            'Shows marker at the center of a mesh or area,\n' ..
            'or at the world position of a shapeless node.')
    end

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Show bounding box:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsLongComboRowWidth - ImGui.GetCursorPosX())
    state, changed = ImGui.Combo('##BoundingBoxMode', BoundingBoxMode.values[userState.boundingBoxMode] - 1, viewData.boundingBoxModeOptions, #viewData.boundingBoxModeOptions)
    if changed then
        userState.boundingBoxMode = BoundingBoxMode.values[state + 1]
    end
    ImGui.EndGroup()
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(
            'The bounding box may differ from the actual shape of the area,\n' ..
            'but helps to understand its general location and boundaries.')
    end

    ImGui.Spacing()

    state, changed = ImGui.Checkbox('Show distance to the marker', userState.showMarkerDistance)
    if changed then
        userState.showMarkerDistance = state
    end

    state, changed = ImGui.Checkbox('Show distances to the corners of bounding box', userState.showBoundingBoxDistances)
    if changed then
        userState.showBoundingBoxDistances = state
    end

    ImGui.Spacing()
    ImGui.Spacing()
    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.SetWindowFontScale(0.85)
    ImGui.Text('INSPECTING')
    ImGui.SetWindowFontScale(1.0)
    ImGui.PopStyleColor()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Targeting mode:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsMiddleComboRowWidth - ImGui.GetCursorPosX())
    state, changed = ImGui.Combo('##TargetingMode', TargetingMode.values[userState.targetingMode] - 1, viewData.targetingModeOptions, #viewData.targetingModeOptions)
    if changed then
        userState.targetingMode = TargetingMode.values[state + 1]
    end
    ImGui.EndGroup()
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        local cursorY = ImGui.GetCursorPosY()
        ImGui.Dummy(220 * viewStyle.viewScale, 0)
        ImGui.SetCursorPosY(cursorY)
        ImGui.Text(viewData.targetingModeOptions[1])
        ImGui.TextWrapped(
            'Uses the same ray casting method and physical data as during normal gameplay, ' ..
            'pixel accurate but cannot target non-collision meshes and decals.')
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Text(viewData.targetingModeOptions[2])
        ImGui.TextWrapped(
            'Uses alternative ray casting method based on static bounding boxes of world nodes, ' ..
            'ignores transparency and generally less accurate but can target non-collision meshes and decals.')
        ImGui.EndTooltip()
    end

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Max static targets:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsShortInputWidth)
    state, changed = ImGui.InputInt('##StaticMeshTargets', userState.maxTargets, 1, 10, ImGuiInputTextFlags.None)
    if changed then
        userState.maxTargets = clamp(state, 1, 16)
    end
    ImGui.EndGroup()
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip('The number of targets closest to the crosshair in Static Bounds mode.')
    end

    ImGui.Spacing()

    state, changed = ImGui.Checkbox('Highlight inspected target', userState.highlightInspectorResult)
    if changed then
        userState.highlightInspectorResult = state
    end

    ImGui.Spacing()
    ImGui.Spacing()
    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.SetWindowFontScale(0.85)
    ImGui.Text('SCANNING')
    ImGui.SetWindowFontScale(1.0)
    ImGui.PopStyleColor()
    ImGui.Separator()
    ImGui.Spacing()

    state, changed = ImGui.Checkbox('Highlight scanned target when hover over', userState.highlightScannerResult)
    if changed then
        userState.highlightScannerResult = state
    end

    --ImGui.Indent(ImGui.GetFrameHeightWithSpacing())
    if not userState.highlightScannerResult then
        ImGui.BeginDisabled()
    end
    state, changed = ImGui.Checkbox('Keep last target highlighted when hover out', userState.keepLastHoveredResultHighlighted)
    if changed then
        userState.keepLastHoveredResultHighlighted = state
    end
    if not userState.highlightScannerResult then
        ImGui.EndDisabled()
    end
    --ImGui.Unindent(ImGui.GetFrameHeightWithSpacing())

    ImGui.Spacing()
    ImGui.Spacing()
    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.SetWindowFontScale(0.85)
    ImGui.Text('LOOKUP')
    ImGui.SetWindowFontScale(1.0)
    ImGui.PopStyleColor()
    ImGui.Separator()
    ImGui.Spacing()

    state, changed = ImGui.Checkbox('Highlight lookup target', userState.highlightLookupResult)
    if changed then
        userState.highlightLookupResult = state
    end
end

-- GUI :: Drawing --

local function getScreenDescriptor(camera)
    local screen = {}
    screen.width, screen.height = GetDisplayResolution()

    screen.centerX = screen.width / 2
    screen.centerY = screen.height / 2

    screen[1] = { x = 0, y = 0 }
    screen[2] = { x = screen.width - 1, y = 0 }
    screen[3] = { x = screen.width - 1, y = screen.height - 1 }
    screen[4] = { x = 0, y = screen.height }

    screen.camera = camera

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
        result.x = clamp(result.x, -0.995, 0.995)
        result.y = clamp(result.y, -0.999, 0.999)
        result.off = false
    end

    result.x = screen.centerX + (result.x * screen.centerX)
    result.y = screen.centerY + (result.y * screen.centerY)

    return result
end

local function getScreenShape(screen, shape)
    local projected = {}
    for i = 1,#shape do
        projected[i] = getScreenPoint(screen, shape[i])
    end
    return projected
end

local function isOffScreenPoint(point)
    return point.off
end

local function isOffScreenShape(points)
    for _, point in ipairs(points) do
        if not isOffScreenPoint(point) then
            return false
        end
    end
    return true
end

local function drawPoint(point, color, radius, thickness)
    if thickness == nil then
        ImGui.ImDrawListAddCircleFilled(ImGui.GetWindowDrawList(), point.x, point.y, radius, color, -1)
    else
        ImGui.ImDrawListAddCircle(ImGui.GetWindowDrawList(), point.x, point.y, radius, color, -1, thickness)
    end
end

local function drawLine(line, color, thickness)
    ImGui.ImDrawListAddLine(ImGui.GetWindowDrawList(),
        line[1].x, line[1].y,
        line[2].x, line[2].y,
        color, thickness or 1)
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

local function drawText(position, color, size, text)
    ImGui.ImDrawListAddText(ImGui.GetWindowDrawList(), size, position.x, position.y, color, tostring(text))
end

local function drawProjectedPoint(screen, point, color, radius, thickness)
    local projected = getScreenPoint(screen, point)
    if not isOffScreenPoint(projected) then
        drawPoint(projected, color, radius, thickness)
    end
end

local function drawProjectedLine(screen, line, color, thickness)
    local projected = getScreenShape(screen, line)
    if not isOffScreenShape(projected) then
        drawLine(projected, color, thickness)
    end
end

local function drawProjectedQuad(screen, quad, color, thickness)
    local projected = getScreenShape(screen, quad)
    if not isOffScreenShape(projected) then
        drawQuad(projected, color, thickness)
    end
end

local function drawProjectedText(screen, position, color, size, text)
    local projected = getScreenPoint(screen, position)
    if not isOffScreenPoint(projected) then
        drawText(projected, color, size, text)
    end
end

local function drawProjectedDistance(screen, position, offsetX, offsetY, textColor, fontSize, fontBold)
    local projected = getScreenPoint(screen, position)
    if not isOffScreenPoint(projected) then
        local distance = Vector4.Distance(screen.camera.position, position)
        local formattedDistance = formatDistance(distance)
        local textWidth, textHeight = ImGui.CalcTextSize(formattedDistance)
        local fontRatio = fontSize / viewStyle.fontSize

        if type(offsetX) == 'number' then
            projected.x = projected.x + offsetX
        else
            projected.x = projected.x - (textWidth * fontRatio / 2.0)
        end

        if type(offsetY) == 'number' then
            projected.y = projected.y + offsetY
        else
            projected.y = projected.y - (textHeight * fontRatio / 2.0)
        end

        drawText(projected, textColor, fontSize, formattedDistance)

        if fontBold then
            drawText(projected, textColor, fontSize, formattedDistance)
        end
    end
end

local function drawProjectedMarker(screen, position, outerColor, innerColor, distanceColor)
    setScreenClamping(true)

    drawProjectedPoint(screen, position, outerColor, 10, 3)
    drawProjectedPoint(screen, position, innerColor, 5)

    if userState.showMarkerDistance then
        drawProjectedDistance(screen, position, true, -32, distanceColor, viewStyle.fontSize, true)
    end

    setScreenClamping(false)
end

local function drawProjectedBox(screen, box, faceColor, edgeColor, verticeColor, frame, fill, fadeWithDistance)
    local vertices = {
        ToVector4{ x = box.Min.x, y = box.Min.y, z = box.Min.z, w = 1.0 },
        ToVector4{ x = box.Min.x, y = box.Min.y, z = box.Max.z, w = 1.0 },
        ToVector4{ x = box.Min.x, y = box.Max.y, z = box.Min.z, w = 1.0 },
        ToVector4{ x = box.Min.x, y = box.Max.y, z = box.Max.z, w = 1.0 },
        ToVector4{ x = box.Max.x, y = box.Min.y, z = box.Min.z, w = 1.0 },
        ToVector4{ x = box.Max.x, y = box.Min.y, z = box.Max.z, w = 1.0 },
        ToVector4{ x = box.Max.x, y = box.Max.y, z = box.Min.z, w = 1.0 },
        ToVector4{ x = box.Max.x, y = box.Max.y, z = box.Max.z, w = 1.0 },
    }

    if fill then
        local faces = {
            { vertices[1], vertices[2], vertices[4], vertices[3] },
            { vertices[2], vertices[4], vertices[8], vertices[6] },
            { vertices[1], vertices[2], vertices[6], vertices[5] },
            { vertices[1], vertices[3], vertices[7], vertices[5] },
            { vertices[5], vertices[7], vertices[8], vertices[6] },
            { vertices[3], vertices[4], vertices[8], vertices[7] },
        }

        for _, face in ipairs(faces) do
            drawProjectedQuad(screen, face, faceColor)
        end
    end

    if frame then
        local edges = {
            { vertices[1], vertices[2] },
            { vertices[2], vertices[4] },
            { vertices[4], vertices[3] },
            { vertices[3], vertices[1] },
            { vertices[5], vertices[6] },
            { vertices[6], vertices[8] },
            { vertices[8], vertices[7] },
            { vertices[7], vertices[5] },
            { vertices[1], vertices[5] },
            { vertices[2], vertices[6] },
            { vertices[3], vertices[7] },
            { vertices[4], vertices[8] },
        }

        if fadeWithDistance then
            local edgeOpacity = opacity(edgeColor)
            for _, edge in ipairs(edges) do
                local distance = Vector4.DistanceToEdge(screen.camera.position, edge[1], edge[2])
                local distanceFactor = (clamp(distance, 10, 1010) - 10) / 1000
                local edgeColorAdjusted = fade(edgeColor, edgeOpacity - 0x80 * distanceFactor)
                drawProjectedLine(screen, edge, edgeColorAdjusted, 1)
            end
        else
            for _, edge in ipairs(edges) do
                drawProjectedLine(screen, edge, edgeColor, 1)
            end
        end

        for _, vertice in ipairs(vertices) do
            drawProjectedPoint(screen, vertice, verticeColor, 1)

            if userState.showBoundingBoxDistances then
                drawProjectedDistance(screen, vertice, 4, -20, verticeColor, viewStyle.fontSize)
            end
        end
    end
end

local function drawProjections()
    if next(highlight.projections) == nil then
        return
    end

    local camera = getCameraData()

    if not camera then
        return
    end

    local screen = getScreenDescriptor(camera)

    ImGui.SetNextWindowSize(screen.width, screen.height, ImGuiCond.Always)
    ImGui.SetNextWindowPos(0, 0, ImGuiCond.Always)

    if ImGui.Begin('Red Hot Tools Projection', true, viewStyle.projectionWindowFlags) then
        for _, projection in pairs(highlight.projections) do
            local target = projection.target

            if projection.showBoundindBox and target.boundingBox then
                local insideColor = fade(projection.color, 0x1D)
                local faceColor = fade(projection.color, 0x0D)
                local edgeColor = fade(projection.color, 0xF0)
                local verticeColor = projection.color

                if insideBox(camera.position, target.boundingBox) then
                    drawQuad(screen, insideColor)
                    drawProjectedBox(screen, target.boundingBox, faceColor, edgeColor, verticeColor, true, false, true)
                else
                    drawProjectedBox(screen, target.boundingBox, faceColor, edgeColor, verticeColor, true, true, true)
                end
            end

            if projection.showMarker and target.position then
                local outerColor = projection.color -- fade(projection.color, 0x77)
                local innerColor = projection.color
                local distanceColor = projection.color

                drawProjectedMarker(screen, target.position, outerColor, innerColor, distanceColor)
            end
        end
    end
end

-- GUI :: Windows --

local function pushWindowStyle()
    local windowX, windowY, condition

    if userState.windowSnapping == WindowSnapping.Disabled then
        condition = ImGuiCond.FirstUseEver
        windowX = viewStyle.windowRightX
        windowY = viewStyle.windowTopY
    elseif userState.windowSnapping == WindowSnapping.TopLeft then
        condition = ImGuiCond.Always
        windowX = viewStyle.windowLeftX
        windowY = viewStyle.windowTopY
    elseif userState.windowSnapping == WindowSnapping.TopRight then
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

local function drawInspectorWindow()
    pushWindowStyle()
    ImGui.Begin('Red Hot Tools', viewStyle.inspectorWindowFlags)

    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - 2)
    drawInspectorContent(true)

    ImGui.End()
    popWindowStyle()
end

local function drawMainWindow()
    pushWindowStyle()
    ImGui.Begin('Red Hot Tools', viewStyle.mainWindowFlags)

    viewState.isWindowOpen = not ImGui.IsWindowCollapsed()
    if viewState.isWindowOpen then
        ImGui.BeginTabBar('Red Hot Tools TabBar')

        local activeTool
        local toolTabs = {
            { id = Feature.Inspect, draw = drawInspectorContent },
            { id = Feature.Scan, draw = drawScannerContent },
            { id = Feature.Lookup, draw = drawLookupContent },
            { id = Feature.Watch, draw = drawWatcherContent },
            { id = Feature.Reload, draw = drawHotReloadContent },
        }

        for _, toolTab in ipairs(toolTabs) do
            local tabLabel = ' ' .. toolTab.id .. ' '
            local tabFlags = ImGuiTabItemFlags.None
            if viewState.isFirstOpen and userState.activeTool == toolTab.id then
                tabFlags = ImGuiTabItemFlags.SetSelected
            end

            if ImGui.BeginTabItem(tabLabel, tabFlags) then
                activeTool = toolTab.id
                ImGui.Spacing()
                toolTab.draw()
                ImGui.EndTabItem()
            end
        end

        if ImGui.BeginTabItem(' Settings ') then
            ImGui.Spacing()
            drawSettingsContent()
            ImGui.EndTabItem()
        end

        userState.activeTool = activeTool
        viewState.isFirstOpen = false
    end

    ImGui.End()
    popWindowStyle()
end

-- GUI :: Events --

registerForEvent('onOverlayOpen', function()
    viewState.isConsoleOpen = true
end)

registerForEvent('onOverlayClose', function()
    viewState.isConsoleOpen = false
    saveUserState()
end)

registerForEvent('onDraw', function()
    if not isPluginFound then
        return
    end

    if not viewState.isConsoleOpen and not userState.showOnScreenDisplay then
        return
    end

    initializeViewStyle()

    if viewState.isConsoleOpen then
        if viewState.isWindowOpen then
            drawProjections()
        end
        drawMainWindow()
    elseif userState.showOnScreenDisplay then
        drawProjections()
        drawInspectorWindow()
    end
end)

-- Bindings --

registerHotkey('ToggleInspector', 'Toggle inspector window', function()
    if not viewState.isConsoleOpen then
        userState.showOnScreenDisplay = not userState.showOnScreenDisplay
        if userState.showOnScreenDisplay then
            userState.activeTool = Feature.Inspect
            viewState.isFirstOpen = true
        end
        saveUserState()
    end
end)

registerHotkey('NextInspectorResult', 'Select next inspected target', function()
    if not viewState.isConsoleOpen and userState.showOnScreenDisplay then
        cycleNextInspectedResult()
    end
end)

registerHotkey('PrevInspectorResult', 'Select previous inspected target', function()
    if not viewState.isConsoleOpen and userState.showOnScreenDisplay then
        cyclePrevInspectedResult()
    end
end)

registerHotkey('ToggleInspectorNodeState', 'Toggle state of inspected target', function()
    if not viewState.isConsoleOpen and userState.showOnScreenDisplay then
        if inspector.active then
            toggleNodeState(inspector.results[inspector.active])
        else
            toggleNodeState()
        end
    end
end)

registerHotkey('CycleTargetingMode', 'Cycle targeting modes', function()
    if not viewState.isConsoleOpen and userState.showOnScreenDisplay then
        local nextModeIndex = TargetingMode.values[userState.targetingMode] + 1
        if nextModeIndex > #TargetingMode.values then
            nextModeIndex = 1
        end
        userState.targetingMode = TargetingMode.values[nextModeIndex]
        saveUserState()
    end
end)

registerHotkey('CycleHighlightColor', 'Cycle highlight colors', function()
    if not viewState.isConsoleOpen and userState.showOnScreenDisplay then
        local nextColorIndex = ColorScheme.values[userState.highlightColor] + 1
        if nextColorIndex > #ColorScheme.values then
            nextColorIndex = 1
        end
        userState.highlightColor = ColorScheme.values[nextColorIndex]
        initializeHighlighting()
        saveUserState()
    end
end)

-- Main --

registerForEvent('onInit', function()
    initializeEnvironment()

    if isPluginFound then
        initializeUserState()
        initializeHighlighting()
        initializeTargeting()
        initializeWatcher()
        initializeViewData()

        Cron.Every(0.2, function()
            if viewState.isConsoleOpen then
                if viewState.isWindowOpen then
                    if userState.activeTool == Feature.Inspect then
                        updateInspector()
                    elseif userState.activeTool == Feature.Scan then
                        updateScanner(userState.scannerDistance, userState.scannerGroup, userState.scannerFilter)
                    elseif userState.activeTool == Feature.Lookup then
                        updateLookup(viewState.lookupQuery)
                    elseif userState.activeTool == Feature.Watch then
                        updateWatcher()
                    end
                end
            elseif userState.showOnScreenDisplay then
                updateInspector()
            end
            updateHighlights()
        end)
    end
end)

registerForEvent('onUpdate', function(delta)
	Cron.Update(delta)
end)

registerForEvent('onShutdown', function()
    disableHighlights()
    saveUserState()
end)

-- API --

return {
    RegisterExtension = registerExtension,
    getLookAtTargets = getLookAtTargets,
    CollectTargetData = resolveTargetData,
    GetInspectorTarget = function()
        return inspector.active and inspector.results[inspector.active] or nil
    end,
    GetInspectorTargets = function()
        return inspector.results
    end,
    GetScannerTargets = function()
        return scanner.results
    end,
    GetLookupTarget = function()
        return lookup.result
    end,
}
