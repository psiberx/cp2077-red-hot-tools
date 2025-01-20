local app, moduleID, modulePath = ...

-- Deps --

local Cron = require('libs/Cron')
local Ref = require('libs/Ref')
local PersistentState = require('libs/PersistentState')
local Enumeration = require('libs/Enumeration')
local ImGuiEx = require('libs/ImGuiEx')
local MathEx = require('libs/MathEx')

-- Utils --

local function isEmpty(value)
    return value == nil or value == 0 or value == '' or value == 'None'
end

local function isNotEmpty(value)
    return value ~= nil and value ~= 0 and value ~= '' and value ~= 'None'
end

-- Game Systems --

local cameraSystem
local targetingSystem
local spatialQuerySystem
local transactionSystem
local inspectionSystem

local function initializeSystems()
    cameraSystem = Game.GetCameraSystem()
    targetingSystem = Game.GetTargetingSystem()
    spatialQuerySystem = Game.GetSpatialQueriesSystem()
    transactionSystem = Game.GetTransactionSystem()
    inspectionSystem = Game.GetWorldInspector()
end

-- User State --

local MainTab = Enumeration('None', 'Inspect', 'Scan', 'Watch', 'Lookup', 'Settings', 'Hotkeys')
local TargetingMode = Enumeration('GamePhysics', 'StaticBounds')
local ColorScheme = Enumeration('Green', 'Red', 'Yellow', 'White', 'Shimmer')
local OutlineMode = Enumeration('ForSupportedObjects', 'Never')
local MarkerMode = Enumeration('Always', 'ForStaticMeshes', 'WhenOutlineIsUnsupported', 'Never')
local BoundingBoxMode = Enumeration('ForAreaNodes', 'Never')
local WindowSnapping = Enumeration('Disabled', 'TopLeft', 'TopRight')

local userState = {}
local userStateSchema = {
    isModuleActive = { type = 'boolean', default = true },
    isOnScreenDisplayActive = { type = 'boolean', default = false },
    selectedTab = { type = MainTab, default = MainTab.Inspect },
    windowSnapping = { type = WindowSnapping, default = WindowSnapping.Disabled },
    scannerFilter = { type = 'string', default = '' },
    scannerGroup = { type = 'string', default = '' },
    scannerDistance = { type = 'number', default = 25.0 },
    frustumDistance = { type = 'number', default = 0.0 },
    targetingDistance = { type = 'number', default = 0.0 },
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

local function syncInspectionSystemState()
    inspectionSystem:SetFrustumDistance(userState.frustumDistance)
    inspectionSystem:SetTargetingDistance(userState.targetingDistance)

    userState.frustumDistance = inspectionSystem:GetFrustumDistance()
    userState.targetingDistance = inspectionSystem:GetTargetingDistance()
    userState.scannerDistance = MathEx.Clamp(userState.scannerDistance, 0.5, userState.frustumDistance)
end

local function initializeUserState()
    PersistentState.Initialize(userState, modulePath .. '/.state', userStateSchema)
    syncInspectionSystemState()
end

local function saveUserState()
    PersistentState.Flush(userState)
end

-- Targeting --

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

local function initializeTargeting()
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
	local camera = getCameraData(maxDistance or userState.targetingDistance)

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
                hash = RedHotTools.GetObjectHash(entity),
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
        local results = inspectionSystem:GetStreamedNodesInCrosshair()

        if #results == 0 then
            return
        end

        while #results > userState.maxTargets do
            table.remove(results)
        end

        return results
    end
end

-- Highlighting --

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

    local showBoundingBox = false
    if not target.isCollisionNode then
        if userState.boundingBoxMode == BoundingBoxMode.ForAreaNodes and (target.isAreaNode or target.isOccluderNode) then
            showBoundingBox = true
        end
    end

    if showMarker or showBoundingBox then
        highlight.projections[target.hash] = {
            target = target,
            color = highlight.color,
            showMarker = showMarker,
            showBoundingBox = showBoundingBox,
        }
    end
end

local function disableHighlight(target)
    applyHighlightEffect(target, false)
    highlight.projections = {}
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

local function highlightTarget(target)
    if target and target.hash then
        highlight.pending = target
    else
        highlight.pending = nil
    end
end

-- Resolving --

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

    for _, component in ipairs(RedHotTools.GetEntityComponents(entity)) do
        local data = {
            componentType = component:GetClassName().value,
            componentName = component:GetName().value,
            componentID = RedHotTools.GetCRUIDHash(component.id),
            appearancePath = RedHotTools.GetResourcePath(RedHotTools.GetComponentAppearanceResourceHash(component)),
            appearanceDef = RedHotTools.GetComponentAppearanceDefinition(component).value,
        }

        if component:IsA('entMeshComponent') or component:IsA('entSkinnedMeshComponent') then
            data.meshPath = RedHotTools.GetResourcePath(component.mesh.hash)
            data.meshAppearance = component.meshAppearance.value
            data.chunkMask = component.chunkMask
        end

        if component:IsA('entMorphTargetSkinnedMeshComponent') then
            data.morphPath = RedHotTools.GetResourcePath(component.morphResource.hash)
            data.meshAppearance = component.meshAppearance.value
            data.chunkMask = component.chunkMask
        end

        if component:IsA('entAnimatedComponent') then
            data.rigPath = RedHotTools.GetReferencePath(component, 'rig')
            data.animGraphPath = RedHotTools.GetReferencePath(component, 'graph')
        end

        if component:IsA('entEffectSpawnerComponent') then
            data.effects = {}
            for _, effectDesc in ipairs(component.effectDescs) do
                table.insert(data.effects, effectDesc.effectName.value)
                --table.insert(data.effects, ('%s\n%s'):format(effectDesc.effectName.value, RedHotTools.GetResourcePath(effectDesc.effect.hash)))
            end
            if #data.effects == 0 then
                data.effects = nil
            end
        end

        local description = { data.componentType, data.componentName }
        data.description = table.concat(description, ' | ')

        data.hash = RedHotTools.GetObjectHash(component)

        table.insert(components, data)
    end

    return components
end

local function resolveVisualTags(entity, owner)
    local visualTags = {}

    for _, tag in ipairs(RedHotTools.GetEntityVisualTags(entity)) do
        table.insert(visualTags, tag.value)
    end

    if entity:IsA('gameItemObject') then
        for _, tag in ipairs(transactionSystem:GetVisualTagsByItemID(entity:GetItemID(), owner)) do
            table.insert(visualTags, tag.value)
        end
    end

    return visualTags
end

local function resolveAttachments(entity)
    if not entity:IsA('gameObject') then
        return {}
    end

    local recordID = entity:GetTDBID()

    if not recordID then
        return {}
    end

    local isItem = entity:IsA('gameItemObject')
    local isGarment = entity:IsA('gameGarmentItemObject')

    local slotIDs = {}

    if isItem then
        for _, slotID in ipairs(entity:GetItemData():GetUsedSlotsOnItem()) do
            table.insert(slotIDs, slotID)
        end
        for _, slotID in ipairs(entity:GetItemData():GetEmptySlotsOnItem()) do
            table.insert(slotIDs, slotID)
        end
    elseif not isGarment then
        slotIDs = TweakDB:GetFlat(TweakDBID.new(recordID, '.attachmentSlots'))
    end

    if not slotIDs or #slotIDs == 0 then
        return {}
    end

    local attachments = {}

    for _, slotID in ipairs(slotIDs) do
        local data = {}
        data.slotID = slotID.value

        local item = transactionSystem:GetItemInSlot(entity, slotID)
        if IsDefined(item) then
            data.itemID = item:GetItemID().tdbid.value
            data.itemType = item:GetClassName().value

            if not item:IsA('gameweaponObject') then
                local templatePath = RedHotTools.GetEntityTemplatePath(item)
                data.templatePath = RedHotTools.GetResourcePath(templatePath.hash)
                data.appearanceName = transactionSystem:GetItemAppearance(entity, item:GetItemID()).value
            end

            data.components = resolveComponents(item)
            data.attachments = resolveAttachments(item)
            data.visualTags = resolveVisualTags(item, entity)

            data.hasComponents = (#data.components > 0)
            data.hasAttachments = (#data.attachments > 0)
            data.hasVisualTags = (#data.visualTags > 0)

            data.hash = RedHotTools.GetObjectHash(item)
        elseif isItem then
             local partID = entity:GetItemData():GetItemPart(slotID):GetItemID().tdbid
             if TDBID.IsValid(partID) then
                 data.itemID = partID.value
             end
        end

        table.insert(attachments, data)
    end

    return attachments
end

local function fillTargetEntityData(target, data)
    if IsDefined(target.entity) then
        local entity = target.entity
        data.entityID = entity:GetEntityID().hash
        data.entityType = entity:GetClassName().value

        local templatePath = RedHotTools.GetEntityTemplatePath(entity)
        data.templatePath = RedHotTools.GetResourcePath(templatePath.hash)
        data.appearanceName = entity:GetCurrentAppearanceName().value

        data.inventory = {}

        if entity:IsA('gameObject') then
            local recordID = entity:GetTDBID()
            if TDBID.IsValid(recordID) then
                data.recordID = recordID.value
            end

            local success, items = transactionSystem:GetItemList(entity)
            if success then
                for _, item in ipairs(items) do
                    local itemID = item:GetID().id.value
                    if isNotEmpty(itemID) then
                        table.insert(data.inventory, itemID)
                    end
                end
                table.sort(data.inventory)
            end
        end

        if entity:IsA('gameLootContainerBase') then
            data.lootTables = {}
            for _, lootTableID in ipairs(entity.lootTables) do
                if isNotEmpty(lootTableID.value) then
                    table.insert(data.lootTables, lootTableID.value)
                end
            end
        end

        data.components = resolveComponents(entity)
        data.attachments = resolveAttachments(entity)
        data.visualTags = resolveVisualTags(entity)

        data.hasInventory = (#data.inventory > 0)
        data.hasComponents = (#data.components > 0)
        data.hasAttachments = (#data.attachments > 0)
        data.hasVisualTags = (#data.visualTags > 0)
    end

    data.entity = target.entity
    data.isEntity = IsDefined(data.entity)
end

local function fillTargetCommunityData(target, data)
    if IsDefined(target.entity) then
        local communityData = inspectionSystem:ResolveCommunityEntryDataFromEntityID(target.entity:GetEntityID().hash)
        if communityData.sectorHash ~= 0 then
            data.communityPath = RedHotTools.GetResourcePath(communityData.sectorHash)
            data.communityIndex = communityData.communityIndex
            data.communityCount = communityData.communityCount
            data.communityID = communityData.communityID.hash
            data.communityEntryName = communityData.entryName.value
            data.communityEntryPhase = communityData.entryPhase.value
            data.communityEntryIndex = communityData.entryIndex
            data.communityEntryCount = communityData.entryCount
        end
    end
end

local function fillTargetNodeData(target, data)
    local sectorData
    if IsDefined(target.nodeInstance) then
        sectorData = inspectionSystem:ResolveSectorDataFromNodeInstance(target.nodeInstance)
    elseif isNotEmpty(target.nodeID) then
        sectorData = inspectionSystem:ResolveSectorDataFromNodeID(target.nodeID)
    end
    if sectorData and sectorData.sectorHash ~= 0 then
        data.sectorPath = RedHotTools.GetResourcePath(sectorData.sectorHash)
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
        data.nodeType = RedHotTools.GetTypeName(node).value

        if RedHotTools.IsInstanceOf(node, 'worldMeshNode')
        or RedHotTools.IsInstanceOf(node, 'worldInstancedMeshNode')
        or RedHotTools.IsInstanceOf(node, 'worldBendedMeshNode')
        or RedHotTools.IsInstanceOf(node, 'worldFoliageNode')
        or RedHotTools.IsInstanceOf(node, 'worldPhysicalDestructionNode') then
            data.meshPath = RedHotTools.GetResourcePath(node.mesh.hash)
            data.meshAppearance = node.meshAppearance.value
        end

        if RedHotTools.IsInstanceOf(node, 'worldTerrainMeshNode') then
            data.meshPath = RedHotTools.GetResourcePath(node.meshRef.hash)
        end

        if RedHotTools.IsInstanceOf(node, 'worldStaticDecalNode') then
            data.materialPath = RedHotTools.GetResourcePath(node.material.hash)
        end

        if RedHotTools.IsInstanceOf(node, 'worldEffectNode') then
            data.effectPath = RedHotTools.GetResourcePath(node.effect.hash)
        end

        if RedHotTools.IsInstanceOf(node, 'worldPopulationSpawnerNode') then
            data.recordID = node.objectRecordId.value
            data.appearanceName = node.appearanceName.value
        end

        if RedHotTools.IsInstanceOf(node, 'worldEntityNode') then
            data.templatePath = RedHotTools.GetResourcePath(node.entityTemplate.hash)
            data.appearanceName = node.appearanceName.value
        end

        if RedHotTools.IsInstanceOf(node, 'worldDeviceNode') then
            data.deviceClass = node.deviceClassName.value
        end

        if RedHotTools.IsInstanceOf(node, 'worldTriggerAreaNode') then
            data.triggerNotifiers = {}
            for _, notifier in ipairs(node.notifiers) do
                table.insert(data.triggerNotifiers, RedHotTools.GetTypeName(notifier).value)
            end
        end

        if RedHotTools.IsInstanceOf(node, 'worldStaticOccluderMeshNode')
        or RedHotTools.IsInstanceOf(node, 'worldInstancedOccluderNode') then
            data.meshPath = RedHotTools.GetResourcePath(node.mesh.hash)
            data.occluderType = node.occluderType.value
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
            data.parentInstance = inspectionSystem:FindStreamedNode(data.parentID).nodeInstance
        end
    end

    data.nodeDefinition = target.nodeDefinition
    data.nodeInstance = target.nodeInstance

    data.isNode = IsDefined(data.nodeInstance) or IsDefined(data.nodeDefinition) or isNotEmpty(data.nodeID)
    data.isAreaNode = data.isNode and RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldAreaShapeNode')
    data.isOccluderNode = data.isNode and RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldStaticOccluderMeshNode')
    data.isProxyMeshNode = data.isNode and RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldPrefabProxyMeshNode')
    data.isCommunityNode = data.isNode and RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldCompiledCommunityAreaNode')
    data.isSpawnerNode = data.isNode and RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldPopulationSpawnerNode')
    data.isVisibleNode = data.isNode and (isNotEmpty(data.meshPath) or isNotEmpty(data.materialPath) or isNotEmpty(data.templatePath))
        or RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldStaticLightNode')
    data.isCollisionNode = data.isNode and RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldCollisionNode')

    if isNotEmpty(data.nodeType) then
        data.nodeGroup = nodeGroupMapping[data.nodeType]
    end
end

local function fillTargetGeomertyData(target, data)
    data.collision = target.collision
    data.distance = target.distance
    data.position = target.position
    data.orientation = target.orientation
    data.boundingBox = target.boundingBox

    if target.testBox and not target.testBox.Min:IsXYZZero() and target.testBox.Min.x <= target.testBox.Max.x then
        data.testBox = target.testBox
        data.position = Game['OperatorAdd;Vector4Vector4;Vector4'](data.testBox.Min, data.testBox:GetExtents())
    end

    if IsDefined(data.nodeInstance) then
        if target.testBox then
            data.nodePosition = data.position
            data.nodeOrientation = data.orientation
            data.nodeScale = data.scale
        else
            local geometry = inspectionSystem:GetStreamedNodeGeometry(data.nodeInstance)
            data.nodePosition = geometry.position
            data.nodeOrientation = geometry.orientation
            data.nodeScale = geometry.scale
        end
    end

    if not data.nodePosition and IsDefined(data.entity) then
        data.entityPosition = data.entity:GetWorldPosition()
        data.entityOrientation = data.entity:GetWorldOrientation()
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
        data.hash = RedHotTools.GetObjectHash(target.nodeInstance)
    elseif IsDefined(target.nodeDefinition) then
        data.hash = RedHotTools.GetObjectHash(target.nodeDefinition)
    elseif IsDefined(target.entity) then
        data.hash = RedHotTools.GetObjectHash(target.entity)
    end
end

local function expandTarget(target)
    if IsDefined(target.entity) and not IsDefined(target.nodeDefinition) then
        local entityID = target.entity:GetEntityID().hash
        local nodeID

        if entityID > 0xFFFFFF then
            nodeID = entityID
        else
            local communityID = inspectionSystem:ResolveCommunityIDFromEntityID(entityID).hash
            if communityID > 0xFFFFFF then
                nodeID = communityID
            end
        end

        if isNotEmpty(nodeID) then
            local streamingData = inspectionSystem:FindStreamedNode(nodeID)
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
    fillTargetCommunityData(target, result)
    fillTargetNodeData(target, result)
    fillTargetGeomertyData(target, result)
    fillTargetDescription(target, result)
    fillTargetHash(target, result)

    return result
end

-- Nodes --

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

-- Inspector --

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

-- Scanner --

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

    for _, target in ipairs(inspectionSystem:GetStreamedNodesInFrustum()) do
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

-- Lookup --

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
            local streamingData = inspectionSystem:FindStreamedNode(lookupHash)
            if IsDefined(streamingData.nodeInstance) then
                target.nodeInstance = streamingData.nodeInstance
                target.nodeDefinition = streamingData.nodeDefinition
            else
                if lookupHash <= 0xFFFFFF then
                    local communityID = inspectionSystem:ResolveCommunityIDFromEntityID(lookupHash).hash
                    if communityID > 0xFFFFFF then
                        streamingData = inspectionSystem:FindStreamedNode(communityID)
                        if IsDefined(streamingData.nodeInstance) then
                            target.nodeInstance = streamingData.nodeInstance
                            target.nodeDefinition = streamingData.nodeDefinition
                        else
                            target.nodeID = communityID
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
                local streamingData = inspectionSystem:FindStreamedNode(resolvedRef.hash)
                target.nodeInstance = streamingData.nodeInstance
                target.nodeDefinition = streamingData.nodeDefinition
                target.nodeID = resolvedRef.hash
            end
        end
    end

    local data = resolveTargetData(target) or {}

    if isNotEmpty(target.resourceHash) then
        data.resolvedPath = RedHotTools.GetResourcePath(target.resourceHash)
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

-- Watcher --

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

    if watcher.targets[key] then
        watcher.targets[key] = nil
        watcher.results[key] = nil
        watcher.numTargets = watcher.numTargets - 1

        collectgarbage()
    end
end

local function initializeWatcher()
    watchTarget(GetPlayer())
    watchTarget(GetMountedVehicle(GetPlayer()))

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

    ObserveAfter('vehicleBaseObject', 'OnVehicleFinishedMounting', function(this, event)
        if this:IsPlayerVehicle() then
            if event.character:IsPlayer() and event.isMounting then
                watchTarget(this)
            else
                forgetTarget(this)
            end
        end
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
    isWindowExpanded = true,
    lookupQuery = '',
}

local viewData = {
    maxInputLen = 512,
}

local viewStyle = {
    labelTextColor = 0xFFA5A19B,
    mutedTextColor = 0xFFA5A19B,
    hintTextColor = 0x66FFFFFF,
    dangerTextColor = 0xFF6666FF,
    disabledButtonColor = 0xFF4F4F4F,
    groupCaptionSize = 0.75,
}

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
    viewData.targetingModeOptions = ImGuiEx.BuildComboOptions(TargetingMode.values, true)
    viewData.colorSchemeOptions = ImGuiEx.BuildComboOptions(ColorScheme.values)
    viewData.outlineModeOptions = ImGuiEx.BuildComboOptions(OutlineMode.values)
    viewData.markerModeOptions = ImGuiEx.BuildComboOptions(MarkerMode.values)
    viewData.boundingBoxModeOptions = ImGuiEx.BuildComboOptions(BoundingBoxMode.values)
    viewData.windowSnappingOptions = ImGuiEx.BuildComboOptions(WindowSnapping.values, true)
    viewData.nodeGroupOptions = buildMappingOptions(nodeGroupMapping, 'All')
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
        viewStyle.windowHeight = 0
        viewStyle.windowTopY = 4
        viewStyle.windowLeftX = 4
        viewStyle.windowRightX = screenX - viewStyle.windowFullWidth - 4
        viewStyle.windowDefaultX = (screenX - viewStyle.windowFullWidth - 4) / 2
        viewStyle.windowDefaultY = (screenY - 100) / 2

        viewStyle.mainWindowFlags = ImGuiWindowFlags.NoResize
            + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse
        viewStyle.inspectorWindowFlags = ImGuiWindowFlags.NoResize
            + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse
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

    for _, plugin in ipairs(app.getRegisteredExtensions()) do
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

local function validateArrayField(data, field)
    return type(data[field.name]) == 'table' and #data[field.name] > 0
end

local function formatDistance(data)
    return ('%.2fm'):format(type(data) == 'table' and data.distance or data)
end

local function isValidNodeIndex(data)
    return type(data.instanceIndex) == 'number' and data.instanceIndex >= 0
        and type(data.instanceCount) == 'number' and data.instanceCount > 0
end

local function isValidCommunityIndex(data)
    return type(data.communityIndex) == 'number' and data.communityIndex >= 0
        and type(data.communityCount) == 'number' and data.communityCount > 0
end

local function isValidCommunityEntryIndex(data)
    return type(data.communityEntryIndex) == 'number' and data.communityEntryIndex >= 0
        and type(data.communityEntryCount) == 'number' and data.communityEntryCount > 0
end

local hex2bin = {
    ['0'] = '0000',
    ['1'] = '0001',
    ['2'] = '0010',
    ['3'] = '0011',
    ['4'] = '0100',
    ['5'] = '0101',
    ['6'] = '0110',
    ['7'] = '0111',
    ['8'] = '1000',
    ['9'] = '1001',
    ['A'] = '1010',
    ['B'] = '1011',
    ['C'] = '1100',
    ['D'] = '1101',
    ['E'] = '1110',
    ['F'] = '1111'
}

local function formatChunkMask(data)
    local value = type(data) == 'table' and data.chunkMask or data
    local bs = {}
    local hs = ('%016X'):format(value)
    local ln = hs:len()
    for i = 1, ln do
        table.insert(bs, hex2bin[hs:sub(i, i)])
    end
    local str = table.concat(bs, ' '):reverse()
    return str:sub(1, 39) .. '\n' .. str:sub(41)
end

local function isValidChunkMask(data)
    return type(data.chunkMask) == 'cdata' or type(data.chunkMask) == 'number'
end

local function formatAppearanceSource(data)
    return data.appearanceDef .. ' @ ' .. data.appearancePath
end

local function isValidAppearanceSource(data)
    return isNotEmpty(data.appearancePath) and isNotEmpty(data.appearanceDef)
end

local function validatePosition(data, field)
    local vec = data[field.name]
    return vec and (vec.x ~= 0 or vec.y ~= 0 or vec.z ~= 0)
end

local function formatPosition(data, field)
    local vec = data[field.name]
    return ('%.3f, %.3f, %.3f, %.3f'):format(vec.x, vec.y, vec.z, vec.w):gsub('%.000', '.0')
end

local function validateOrientation(data, field)
    local quat = data[field.name]
    return quat and (quat.i ~= 0 or quat.j ~= 0 or quat.k ~= 0 or quat.r ~= 1)
end

local function formatOrientation(data, field)
    local quat = data[field.name]
    return ('%.3f, %.3f, %.3f, %.3f'):format(quat.i, quat.j, quat.k, quat.r):gsub('%.000', '.0')
end

local function validateScale(data, field)
    local vec = data[field.name]
    return vec and (vec.x ~= 1 or vec.y ~= 1 or vec.z ~= 1)
end

local function formatScale(data, field)
    local vec = data[field.name]
    return ('%.3f, %.3f, %.3f'):format(vec.x, vec.y, vec.z):gsub('%.000', '.0')
end

local resultSchema = {
    {
        { name = 'nodeType', label = 'Node Type:' },
        { name = 'nodeID', label = 'Node ID:', format = '%u' },
        { name = 'nodeRef', label = 'Node Ref:', wrap = true },
        { name = 'parentRef', label = 'Parent Ref:', wrap = true },
        { name = 'nodePosition', label = 'Node Position:', format = formatPosition, validate = validatePosition },
        { name = 'nodeOrientation', label = 'Node Orientation:', format = formatOrientation, validate = validateOrientation },
        { name = 'nodeScale', label = 'Node Scale:', format = formatScale, validate = validateScale },
        { name = 'sectorPath', label = 'Node Sector:', wrap = true },
        { name = 'nodeIndex', label = 'Node Definition:', format = '%d', validate = isValidNodeIndex },
        { name = 'nodeCount', label = '/', format = '%d', inline = true, validate = isValidNodeIndex },
        { name = 'instanceIndex', label = 'Node Instance:', format = '%d', validate = isValidNodeIndex },
        { name = 'instanceCount', label = '/', format = '%d', inline = true, validate = isValidNodeIndex },
    },
    {
        { name = 'communityID', label = 'Community ID:', format = '%u' },
        { name = 'communityEntryName', label = 'Community Entry Name:' },
        { name = 'communityEntryPhase', label = 'Community Entry Phase:' },
        { name = 'communityPath', label = 'Community Sector:', wrap = true },
        { name = 'communityIndex', label = 'Community Index:', format = '%d', validate = isValidCommunityIndex },
        { name = 'communityCount', label = '/', format = '%d', inline = true, validate = isValidCommunityIndex },
        { name = 'communityEntryIndex', label = 'Community Entry Index:', format = '%d', validate = isValidCommunityEntryIndex },
        { name = 'communityEntryCount', label = '/', format = '%d', inline = true, validate = isValidCommunityEntryIndex },
    },
    {
        { name = 'entityType', label = 'Entity Type:' },
        { name = 'entityID', label = 'Entity ID:', format = '%u' },
        { name = 'recordID', label = 'Record ID:' },
        { name = 'templatePath', label = 'Entity Template:', wrap = true },
        { name = 'appearanceName', label = 'Entity Appearance:', wrap = true },
        { name = 'deviceClass', label = 'Device Class:' },
        { name = 'meshPath', label = 'Mesh Resource:', wrap = true },
        { name = 'meshAppearance', label = 'Mesh Appearance:', wrap = true },
        { name = 'materialPath', label = 'Material:', wrap = true },
        { name = 'effectPath', label = 'Effect:', wrap = true },
        { name = 'triggerNotifiers', label = 'Trigger Notifiers:', format = formatArrayField, validate = validateArrayField },
        { name = 'lootTables', label = 'Loot Tables:', format = formatArrayField, validate = validateArrayField },
        { name = 'occluderType', label = 'Occluder Type:' },
        { name = 'entityPosition', label = 'Entity Position:', format = formatPosition },
        { name = 'entityOrientation', label = 'Entity Orientation:', format = formatOrientation },
    },
    {
        { name = 'resolvedPath', label = 'Resource:', wrap = true },
        { name = 'resolvedName', label = 'CName:', wrap = true },
        { name = 'resolvedTDBID', label = 'TweakDBID:', wrap = true },
    }
}

local componentSchema = {
    { name = 'componentType', label = 'Type:' },
    { name = 'componentName', label = 'Name:', wrap = true },
    { name = 'componentID', label = 'ID:', format = '%u' },
    { name = 'rigPath', label = 'Rig:', wrap = true },
    { name = 'animGraphPath', label = 'Graph:', wrap = true },
    { name = 'morphPath', label = 'Morph Target:', wrap = true },
    { name = 'meshPath', label = 'Mesh:', wrap = true },
    { name = 'meshAppearance', label = 'Appearance:', wrap = true },
    { name = 'chunkMask', label = 'Chunk Mask:', wrap = true, format = formatChunkMask, validate = isValidChunkMask },
    { name = 'effects', label = 'Effects:', format = formatArrayField, validate = validateArrayField, wrap = true },
    { name = 'appearancePath', label = 'Source:', format = formatAppearanceSource, validate = isValidAppearanceSource, wrap = true },
}

local attachmentSchema = {
    { name = 'slotID', label = 'Slot ID:' },
    { name = 'itemID', label = 'Item ID:', wrap = true },
    { name = 'itemType', label = 'Item Type:' },
    { name = 'templatePath', label = 'Item Template:', wrap = true },
    { name = 'appearanceName', label = 'Item Appearance:', wrap = true },
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

local function drawComponents(components)
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
end

local function drawItemList(items)
    for _, item in ipairs(items) do
        ImGui.Selectable(tostring(item))
        if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
            ImGui.SetClipboardText(tostring(item))
        end
    end
end

local function drawAttachments(attachments)
    for _, attachmentData in ipairs(attachments) do
        local flags = ImGuiTreeNodeFlags.SpanFullWidth
        if not attachmentData.itemID then
            flags = flags + ImGuiTreeNodeFlags.Leaf
        end

        if ImGui.TreeNodeEx(attachmentData.slotID .. '##' .. tostring(attachmentData.hash), flags) then
            if attachmentData.itemID then
                for _, field in ipairs(attachmentSchema) do
                    if isVisibleField(field, attachmentData) then
                        drawField(field, attachmentData)
                    end
                end

                if attachmentData.hasComponents then
                    if ImGui.TreeNodeEx(('Components (%d)##Components'):format(#attachmentData.components), ImGuiTreeNodeFlags.SpanFullWidth) then
                        drawComponents(attachmentData.components)
                        ImGui.TreePop()
                    end
                end

                if attachmentData.hasAttachments then
                    if ImGui.TreeNodeEx(('Attachments (%d)##Attachments'):format(#attachmentData.attachments), ImGuiTreeNodeFlags.SpanFullWidth) then
                        drawAttachments(attachmentData.attachments)
                        ImGui.TreePop()
                    end
                end

                if attachmentData.hasVisualTags then
                    if ImGui.TreeNodeEx(('Visual Tags (%d)##VisualTags'):format(#attachmentData.visualTags), ImGuiTreeNodeFlags.SpanFullWidth) then
                        drawItemList(attachmentData.visualTags)
                        ImGui.TreePop()
                    end
                end
            end

            ImGui.TreePop()
        end
    end
end

local function drawFieldset(targetData, withSeparators, withExtras, withExtrasFrame)
    if withSeparators == nil then
        withSeparators = true
    end

    if withExtras == nil then
        withExtras = true
    end

    if withExtrasFrame == nil then
        withExtrasFrame = false
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

    if withExtras then
        local hasExtras = targetData.hasComponents or targetData.hasAttachments or targetData.hasInventory or targetData.hasVisualTags

        if withSeparators and hasExtras then
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()
        end

        if hasExtras and withExtrasFrame then
            ImGui.BeginChildFrame(1, 0, 10 * ImGui.GetFrameHeightWithSpacing())
        end

        if targetData.hasComponents then
            if ImGui.TreeNodeEx(('Components (%d)##Components'):format(#targetData.components), ImGuiTreeNodeFlags.SpanFullWidth) then
                drawComponents(targetData.components)
                ImGui.TreePop()
            end
        end

        if targetData.hasAttachments then
            if ImGui.TreeNodeEx(('Attachments (%d)##Attachments'):format(#targetData.attachments), ImGuiTreeNodeFlags.SpanFullWidth) then
                drawAttachments(targetData.attachments)
                ImGui.TreePop()
            end
        end

        if targetData.hasInventory then
            if ImGui.TreeNodeEx(('Inventory (%d)##Inventory'):format(#targetData.inventory), ImGuiTreeNodeFlags.SpanFullWidth) then
                drawItemList(targetData.inventory)
                ImGui.TreePop()
            end
        end

        if targetData.hasVisualTags then
            if ImGui.TreeNodeEx(('Visual Tags (%d)##VisualTags'):format(#targetData.visualTags), ImGuiTreeNodeFlags.SpanFullWidth) then
                drawItemList(targetData.visualTags)
                ImGui.TreePop()
            end
        end

        if hasExtras and withExtrasFrame then
            ImGui.EndChildFrame()
        end
    end

    ImGui.PopStyleColor()
    ImGui.PopStyleVar(2)

    local actions = getTargetActions(targetData, withExtras)
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
        drawFieldset(inspector.results[inspector.active], true, not isModal, true)
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
                userState.scannerFilter = ImGuiEx.SanitizeInputText(filter)
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
            local distance, distanceChanged = ImGui.InputFloat('##ScannerDistance', userState.scannerDistance, 1.0, 10.0, '%.1fm', ImGuiInputTextFlags.None)
            if distanceChanged then
                userState.scannerDistance = MathEx.Clamp(distance, 0.5, userState.frustumDistance)
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

            ImGui.SameLine()
            if ImGui.Button('Copy sectors') then
                local sectors = {}
                for _, result in ipairs(scanner.filtered) do
                    if isNotEmpty(result.sectorPath) and not sectors[result.sectorPath] then
                        sectors[result.sectorPath] = result.sectorPath
                        table.insert(sectors, result.sectorPath)
                    end
                end
                table.sort(sectors)
                ImGui.SetClipboardText(table.concat(sectors, '\n'))
            end

            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()

            if #scanner.filtered > 0 then
                ImGui.PushStyleVar(ImGuiStyleVar.IndentSpacing, 0)
                ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
                ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
                ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)

                local visibleRows = MathEx.Clamp(#scanner.filtered, 14, 18)
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
                        drawFieldset(result, false, true, false)
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
    ImGui.TextWrapped('Search world nodes and spawned entities by their identities.')
    ImGui.Spacing()
    ImGui.SetNextItemWidth(viewStyle.windowWidth)
    ImGui.PushStyleColor(ImGuiCol.TextDisabled, viewStyle.hintTextColor)
    local query, queryChanged = ImGui.InputTextWithHint('##LookupQuery', 'Enter node reference or entity id or hash', viewState.lookupQuery, viewData.maxInputLen)
    if queryChanged then
        viewState.lookupQuery = ImGuiEx.SanitizeInputText(query)
    end
    ImGui.PopStyleColor()

    if lookup.result then
        if not lookup.empty then
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()
            drawFieldset(lookup.result, true, true, true)
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

        local visibleRows = MathEx.Clamp(watcher.numTargets, 14, 18)
        ImGui.BeginChildFrame(1, 0, visibleRows * ImGui.GetFrameHeightWithSpacing())

        for _, result in pairs(watcher.results) do
            if ImGui.TreeNodeEx(result.description, ImGuiTreeNodeFlags.SpanFullWidth) then
                drawFieldset(result, false, true, false)
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
    ImGui.Text('HIGHLIGHTING')
    ImGui.SetWindowFontScale(1.0)
    ImGui.PopStyleColor()

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
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.SetWindowFontScale(viewStyle.groupCaptionSize)
    ImGui.Text('WORLD INSPECTOR')
    ImGui.SetWindowFontScale(1.0)
    ImGui.PopStyleColor()

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
    ImGui.Text('Max targeting distance:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsMiddleInputWidth)
    state, changed = ImGui.InputFloat('##TargetingDistance', userState.targetingDistance, 1.0, 10.0, '%.1fm', ImGuiInputTextFlags.None)
    if changed then
        userState.targetingDistance = state
        syncInspectionSystemState()
    end

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Max static targets:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsShortInputWidth)
    state, changed = ImGui.InputInt('##StaticMeshTargets', userState.maxTargets, 1, 10, ImGuiInputTextFlags.None)
    if changed then
        userState.maxTargets = MathEx.Clamp(state, 1, 16)
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
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.SetWindowFontScale(viewStyle.groupCaptionSize)
    ImGui.Text('WORLD SCANNER')
    ImGui.SetWindowFontScale(1.0)
    ImGui.PopStyleColor()

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Max scanning distance:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsMiddleInputWidth)
    state, changed = ImGui.InputFloat('##FrustumDistance', userState.frustumDistance, 1.0, 10.0, '%.1fm', ImGuiInputTextFlags.None)
    if changed then
        userState.frustumDistance = state
        syncInspectionSystemState()
    end

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

    --[[
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
    ImGui.SetWindowFontScale(viewStyle.groupCaptionSize)
    ImGui.Text('LOOKUP')
    ImGui.SetWindowFontScale(1.0)
    ImGui.PopStyleColor()

    ImGui.Spacing()

    state, changed = ImGui.Checkbox('Highlight lookup target', userState.highlightLookupResult)
    if changed then
        userState.highlightLookupResult = state
    end
    --]]
end

-- GUI :: Hotkeys --

local function drawHotkeysContent()
    app.drawHotkeys(moduleID)
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
        result.x = MathEx.Clamp(result.x, -0.995, 0.995)
        result.y = MathEx.Clamp(result.y, -0.999, 0.999)
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

local function insideBox(point, box)
    return point.x >= box.Min.x and point.y >= box.Min.y and point.z >= box.Min.z
        and point.x <= box.Max.x and point.y <= box.Max.y and point.z <= box.Max.z
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

--local function drawProjectedText(screen, position, color, size, text)
--    local projected = getScreenPoint(screen, position)
--    if not isOffScreenPoint(projected) then
--        drawText(projected, color, size, text)
--    end
--end

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

local function makeCubeFromBox(box, position, orientation)
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

    for i, vertex in ipairs(vertices) do
        vertex = orientation:Transform(vertex)
        vertex = Game['OperatorAdd;Vector4Vector4;Vector4'](position, vertex)
        vertices[i] = vertex
    end

    return vertices
end

local function drawProjectedCube(screen, vertices, faceColor, edgeColor, verticeColor, frame, fill, fadeWithDistance)
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
            local edgeOpacity = ImGuiEx.Opacity(edgeColor)
            for _, edge in ipairs(edges) do
                local distance = Vector4.DistanceToEdge(screen.camera.position, edge[1], edge[2])
                local distanceFactor = (MathEx.Clamp(distance, 10, 1010) - 10) / 1000
                local edgeColorAdjusted = ImGuiEx.Fade(edgeColor, edgeOpacity - 0x80 * distanceFactor)
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
    if not userState.isModuleActive then
        return
    end

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

    if ImGui.Begin('##RHT:WorldTools:Projections', true, viewStyle.projectionWindowFlags) then
        for _, projection in pairs(highlight.projections) do
            local target = projection.target

            if projection.showBoundingBox and target.boundingBox then
                local insideColor = ImGuiEx.Fade(projection.color, 0x1D)
                local faceColor = ImGuiEx.Fade(projection.color, 0x0D)
                local edgeColor = ImGuiEx.Fade(projection.color, 0xF0)
                local verticeColor = projection.color
                local visualBox = makeCubeFromBox(target.boundingBox, target.position, target.orientation)

                if target.testBox and insideBox(camera.position, target.testBox) then
                    drawQuad(screen, insideColor)
                    drawProjectedCube(screen, visualBox, faceColor, edgeColor, verticeColor, true, false, true)
                else
                    drawProjectedCube(screen, visualBox, faceColor, edgeColor, verticeColor, true, true, true)
                end
            end

            if projection.showMarker and target.position then
                local outerColor = projection.color
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
        windowX = viewStyle.windowDefaultX
        windowY = viewStyle.windowDefaultY
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
    ImGui.Begin('World Inspector##RHT:WorldTools', viewStyle.inspectorWindowFlags)

    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - 2)
    drawInspectorContent(true)

    ImGui.End()
    popWindowStyle()
end

local function drawMainWindow()
    pushWindowStyle()

    viewState.isWindowOpen = ImGuiEx.Begin('World Inspector##RHT:WorldTools', app.canCloseTools(), viewStyle.mainWindowFlags)
    viewState.isWindowExpanded = not ImGui.IsWindowCollapsed()

    if viewState.isWindowOpen and viewState.isWindowExpanded then
        app.drawSharedMenu(moduleID)

        ImGui.BeginTabBar('##RHT:WorldToolsTabBar')

        local selectedTab
        local featureTabs = {
            { id = MainTab.Inspect, draw = drawInspectorContent },
            { id = MainTab.Scan, draw = drawScannerContent },
            { id = MainTab.Lookup, draw = drawLookupContent },
            { id = MainTab.Watch, draw = drawWatcherContent },
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

        ImGui.EndTabBar()

        userState.selectedTab = selectedTab
        viewState.isFirstOpen = false
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
            drawProjections()
        end
        drawMainWindow()
    elseif userState.isOnScreenDisplayActive then
        drawProjections()
        drawInspectorWindow()
    end
end

local function onOverlayOpen()
    viewState.isConsoleOpen = true
end

local function onOverlayClose()
    viewState.isConsoleOpen = false
    saveUserState()
end

-- Hotkeys --

local function onToggleInspectorHotkey()
    if not viewState.isConsoleOpen then
        userState.isOnScreenDisplayActive = not userState.isOnScreenDisplayActive
        if userState.isOnScreenDisplayActive then
            userState.isModuleActive = true
            viewState.isFirstOpen = true
            userState.selectedTab = MainTab.Inspect
        end
        saveUserState()
    end
end

local function onSelectNextResultHotkey()
    if not viewState.isConsoleOpen and userState.isOnScreenDisplayActive then
        cycleNextInspectedResult()
    end
end

local function onSelectPrevResultHotkey()
    if not viewState.isConsoleOpen and userState.isOnScreenDisplayActive then
        cyclePrevInspectedResult()
    end
end

local function onToggleTargetStateHotkey()
    if not viewState.isConsoleOpen and userState.isOnScreenDisplayActive then
        if inspector.active then
            toggleNodeState(inspector.results[inspector.active])
        else
            toggleNodeState()
        end
    end
end

local function onCycleTargetingModeHotkey()
    if not viewState.isConsoleOpen and userState.isOnScreenDisplayActive then
        local nextModeIndex = TargetingMode.values[userState.targetingMode] + 1
        if nextModeIndex > #TargetingMode.values then
            nextModeIndex = 1
        end
        userState.targetingMode = TargetingMode.values[nextModeIndex]
        saveUserState()
    end
end

--local function onCycleHighlightColorHotkey()
--    if not viewState.isConsoleOpen and userState.isOnScreenDisplayActive then
--        local nextColorIndex = ColorScheme.values[userState.highlightColor] + 1
--        if nextColorIndex > #ColorScheme.values then
--            nextColorIndex = 1
--        end
--        userState.highlightColor = ColorScheme.values[nextColorIndex]
--        initializeHighlighting()
--        saveUserState()
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
    initializeHighlighting()
    initializeTargeting()
    initializeWatcher()
    initializeViewData()

    Cron.Every(0.2, function()
        if userState.isModuleActive then
            if viewState.isConsoleOpen then
                if viewState.isWindowExpanded then
                    if userState.selectedTab == MainTab.Inspect then
                        updateInspector()
                    elseif userState.selectedTab == MainTab.Scan then
                        updateScanner(userState.scannerDistance, userState.scannerGroup, userState.scannerFilter)
                    elseif userState.selectedTab == MainTab.Lookup then
                        updateLookup(viewState.lookupQuery)
                    elseif userState.selectedTab == MainTab.Watch then
                        updateWatcher()
                    end
                end
            elseif userState.isOnScreenDisplayActive then
                updateInspector()
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
    events = {
        onInit = onInit,
        onShutdown = onShutdown,
        onOverlayOpen = onOverlayOpen,
        onOverlayClose = onOverlayClose,
        onDraw = onDraw,
    },
    tools = {
        { id = 'WorldInspector', label = 'World Inspector', isActive = isActive, setActive = setActive }
    },
    hotkeys = {
        { id = 'ToggleWorldInspector', group = 'World Inspector', label = 'Toggle overlay', callback = onToggleInspectorHotkey },
        { id = 'CycleTargetingMode', group = 'World Inspector', label = 'Cycle targeting modes', callback = onCycleTargetingModeHotkey },
        { id = 'ToggleTargetState', group = 'World Inspector', label = 'Toggle target visibility', callback = onToggleTargetStateHotkey },
        { id = 'SelectNextResult', group = 'Target Control', label = 'Select next target', callback = onSelectNextResultHotkey },
        { id = 'SelectPrevResult', group = 'Target Control', label = 'Select previous target', callback = onSelectPrevResultHotkey },
    },
    publicApi = {
        GetWorldInspectorTarget = function()
            return inspector.active and inspector.results[inspector.active] or nil
        end,
        GetWorldInspectorTargets = function()
            return inspector.results
        end,
        GetWorldScannerResults = function()
            return scanner.results
        end,
        GetWorldScannerFilteredResults = function ()
            return scanner.filtered
        end,
        GetLookupResult = function()
            return lookup.result
        end,
        GetLookAtObjects = getLookAtTargets,
        ResolveObjectData = resolveTargetData,
    }
}
