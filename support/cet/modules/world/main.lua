local app, moduleID, modulePath = ...

-- Deps --

local Cron = require('libs/Cron')
local Ref = require('libs/Ref')
local GameSession = require('libs/GameSession')
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

local function firstNotEmpty(...)
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        if isNotEmpty(v) then
            return v
        end
    end
    return nil
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

local MainTab = Enumeration('None', 'Inspect', 'Scan', 'Watch', 'Lookup', 'Streaming', 'Settings', 'Hotkeys')
local TargetingMode = Enumeration('GamePhysics', 'StaticBounds')
local CollisionGranularity = Enumeration('Actor', 'Shape')
local OutlineMode = Enumeration('ForSupportedTargets', 'Never')
local BoundingBoxMode = Enumeration('Always', 'ForStaticTargets', 'ForInvisibleTargets', 'Never')
local MarkerMode = Enumeration('Always', 'ForStaticTargets', 'ForInvisibleTargets', 'Never')
local WindowSnapping = Enumeration('Disabled', 'TopLeft', 'TopRight')

local userState = {
    schema = {
        isModuleActive = { type = 'boolean', default = true },
        isOnScreenDisplayActive = { type = 'boolean', default = false },
        selectedTab = { type = MainTab, default = MainTab.Inspect },
        windowSnapping = { type = WindowSnapping, default = WindowSnapping.Disabled },
        scannerFilter = { type = 'string', default = '' },
        scannerGroup = { type = 'string', default = '' },
        scannerDistance = { type = 'number', default = 25.0 },
        frustumDistance = { type = 'number', default = 0.0 },
        targetingDistance = { type = 'number', default = 0.0 },
        outlineMode = { type = OutlineMode, default = OutlineMode.ForSupportedTargets },
        markerMode = { type = MarkerMode, default = MarkerMode.Always },
        boundingBoxMode = { type = BoundingBoxMode, default = BoundingBoxMode.Always },
        showMarkerDistance = { type = 'boolean', default = true },
        showBoundingBoxDistances = { type = 'boolean', default = true },
        targetingMode = { type = TargetingMode, default = TargetingMode.GamePhysics },
        collisionGranularity = { type = CollisionGranularity, default = CollisionGranularity.Actor },
        maxTargets = { type = 'number', default = 16 },
        cycleInspectorResults = { type = 'boolean', default = false },
        highlightInspectorResult = { type = 'boolean', default = true },
        highlightScannerResult = { type = 'boolean', default = true },
        highlightLookupResult = { type = 'boolean', default = false },
        keepLastHoveredResultHighlighted = { type = 'boolean', default = true },
        syncObserverPositionWithPlayer = { type = 'boolean', default = true },
        windowWidth = { type = 'number', default = 0 },
        windowHeight = { type = 'number', default = 0 },
    },
}

function userState.syncInspectionSystem()
    inspectionSystem:SetFrustumDistance(userState.frustumDistance)
    inspectionSystem:SetTargetingDistance(userState.targetingDistance)

    userState.frustumDistance = inspectionSystem:GetFrustumDistance()
    userState.targetingDistance = inspectionSystem:GetTargetingDistance()
    userState.scannerDistance = MathEx.Clamp(userState.scannerDistance, 0.5, userState.frustumDistance)
end

function userState.syncWindowMetrics()
    userState.windowWidth, userState.windowHeight = ImGui.GetWindowSize()
end

function userState.initialize()
    PersistentState.Initialize(userState, modulePath .. '/.state', userState.schema)
    userState.syncInspectionSystem()
end

function userState.save()
    PersistentState.Flush(userState)
end

-- Targeting --

local targeting = {
    ready = false,
    paused = false,
    collisionGroups = require(modulePath .. '/data/collision-groups'),
}

function targeting.initialize()
    for _, collision in ipairs(targeting.collisionGroups) do
        collision.name = StringToName(collision.name)
    end

    GameSession.OnStart(function()
        targeting.ready = true
    end)

    GameSession.OnEnd(function()
        targeting.ready = false
    end)

    GameSession.OnPause(function()
        targeting.paused = true
    end)

    GameSession.OnResume(function()
        targeting.paused = false
    end)

    targeting.ready = GameSession.IsLoaded()
    targeting.paused = GameSession.IsPaused()
end

function targeting.getCameraData(distance)
	local player = GetPlayer()

	if not IsDefined(player) or IsDefined(GetMountedVehicle(player)) or IsDefined(player:GetActiveWeapon()) then
        return nil
	end

    local position, forward = targetingSystem:GetDefaultCrosshairData(player)
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
        distance = distance,
        instigator = Ref.Weak(player),
        interior = IsEntityInInteriorArea(player),
        world = player:GetWorldPosition(),
        nearPlane = {
            origin = position,
            normal = forward,
        },
    }
end

function targeting.getLookAtTargets(maxDistance)
	if not targeting.ready or not inspectionSystem:IsReady() then
        return
	end

	if maxDistance == nil then
        maxDistance = userState.targetingDistance
	end

	local camera = targeting.getCameraData(maxDistance)

	if not camera then
        return
	end

	if userState.targetingMode == TargetingMode.GamePhysics then
        local results = {}
        local targetMap = {}

        local component = targetingSystem:GetLookAtComponent(camera.instigator, true, false)
        if IsDefined(component) then
            local entity = component:GetEntity()
            local result = {
                resolved = true,
                hash = RedHotTools.GetObjectHash(entity),
                entity = Ref.Weak(entity),
                component = Ref.Weak(component),
                distance = Vector4.Distance(camera.world, ToVector4(entity:GetWorldPosition())),
                collision = targeting.collisionGroups[1], -- Dynamic
            }

            if entity:IsA('gameObject') and entity:IsNPC() then
                local success, trace = spatialQuerySystem:SyncRaycastByCollisionGroup(camera.position, camera.destination, 'NPCTraceObstacle', false, false)
                if success then
                    local target = inspectionSystem:GetPhysicsTraceObject(trace)
                    if target.resolved and target.hash == result.hash then
                        result.proxyID = target.proxyID
                        result.actorIndex = target.actorIndex
                        result.actorOffset = target.actorOffset
                        result.shapeIndex = target.shapeIndex
                    end
                end
            end

            table.insert(results, result)

            targetMap[tostring(result.hash)] = result
        end

        for _, collision in ipairs(targeting.collisionGroups) do
            local filter = physicsQueryFilter.AddGroup(collision.name)
            local traces = inspectionSystem:SyncRaycastMultiple(camera.position, camera.forward, camera.distance, filter)

            for _, trace in ipairs(traces) do
                local target = inspectionSystem:GetPhysicsTraceObject(trace)
                if target.resolved then
                    if not IsDefined(target.entity) or Ref.NotEquals(target.entity, camera.instigator) then
                        if targetMap[tostring(target.hash)] then
                            local result = targetMap[tostring(target.hash)]
                            if not result.proxyID then
                                result.proxyID = target.proxyID
                                result.actorIndex = target.actorIndex
                                result.actorOffset = target.actorOffset
                                result.shapeIndex = target.shapeIndex
                                result.distance = target.distance
                            end
                        else
                            local result = target
                            result.collision = collision
                            result.distance = result.distance

                            table.insert(results, result)

                            targetMap[tostring(result.hash)] = result
                        end
                    end
                end
            end
        end

        --for _, collision in ipairs(collisionGroups) do
        --    local step = {
        --        position = Vector4.new(
        --            camera.position.x + camera.forward.x * collision.offset,
        --            camera.position.y + camera.forward.y * collision.offset,
        --            camera.position.z + camera.forward.z * collision.offset,
        --            1.0),
        --        distance = collision.offset,
        --    }
        --
        --    while step.distance < maxDistance do
        --        local success, trace = spatialQuerySystem:SyncRaycastByCollisionGroup(step.position, camera.destination, collision.name, false, false)
        --
        --        if not success then
        --            break
        --        end
        --
        --        local target = inspectionSystem:GetPhysicsTraceObject(trace)
        --
        --        if target.resolved then
        --            if not IsDefined(target.entity) or Ref.NotEquals(target.entity, camera.instigator) then
        --                if targetMap[tostring(target.hash)] then
        --                    local result = targetMap[tostring(target.hash)]
        --                    if not result.proxyID then
        --                        result.proxyID = target.proxyID
        --                        result.actorIndex = target.actorIndex
        --                        result.actorOffset = target.actorOffset
        --                        result.shapeIndex = target.shapeIndex
        --                        result.distance = target.distance
        --                    end
        --                else
        --                    local result = target
        --                    result.collision = collision
        --                    result.distance = result.distance + step.distance
        --
        --                    table.insert(results, result)
        --
        --                    targetMap[tostring(result.hash)] = result
        --                end
        --            end
        --        else
        --            --if collision.name.value == 'Shooting' then
        --            --    print(step.distance, success, target.resolved, Vector4.Distance(camera.position, ToVector4(trace.position)))
        --            --end
        --            break
        --        end
        --
        --        step.position = Vector4.new(
        --            trace.position.x + camera.forward.x * collision.step,
        --            trace.position.y + camera.forward.y * collision.step,
        --            trace.position.z + camera.forward.z * collision.step,
        --            1.0)
        --        step.distance = Vector4.Distance(camera.position, step.position)
        --
        --        break
        --    end
        --end

        if #results == 0 then
            return
        end

        table.sort(results, function(a, b)
            return (a.distance + a.collision.tolerance) < (b.distance + b.collision.tolerance)
        end)

        return results
	end

    if userState.targetingMode == TargetingMode.StaticBounds then
        local results = inspectionSystem:GetStreamedNodesInCrosshair()

        if #results == 0 then
            return
        end

        for i = #results, 1, -1 do
            results[i].collision = targeting.collisionGroups[2] -- Static

            if camera.interior and RedHotTools.IsInstanceOf(results[i].nodeDefinition, 'worldStaticLightNode') then
                results[i].interior = true
            end
        end

        if camera.interior then
            table.sort(results, function(a, b)
                if a.interior ~= b.interior then
                    return a.interior
                end
                return (a.distance + a.collision.tolerance) < (b.distance + b.collision.tolerance)
            end)
        end

        return results
    end
end

-- Highlighting --

local highlighting = {
    pending = nil,
    target = nil,
    profile = nil,
    projections = {},
    profiles = require(modulePath .. '/data/highlight-profiles'),
    nodeMapping = require(modulePath .. '/data/highlight-node-mapping'),
}

function highlighting.initialize()
    --
end

function highlighting.resolveProfile(target)
   if target then
       if IsDefined(target.entity) then
           return highlighting.profiles[target.entity:IsA('gameObject') and 'Object' or 'Dynamic']
       end

       if target.nodeType then
            return highlighting.profiles[highlighting.nodeMapping[target.nodeType]]
       end
   end

   return nil
end

function highlighting.applyEffect(target, profile, enabled)
    if not profile or (not profile.focusOutlineIndex and not profile.focusFillIndex) then
        return false
    end

    local effect = entRenderHighlightEvent.new({
        seeThroughWalls = true,
        outlineIndex = enabled and profile.focusOutlineIndex or 0,
        fillIndex = enabled and profile.focusFillIndex or 0,
        opacity = enabled and profile.focusOpacity or 0.0
    })

    if enabled and profile.focusOpacityBoost and not IsEntityInInteriorArea(GetPlayer()) then
        effect.opacity = effect.opacity + profile.focusOpacityBoost
    end

    if IsDefined(target.entity) then
        return inspectionSystem:ApplyHighlightEffect(target.entity, effect)
    end

    if IsDefined(target.component) then
        effect.componentName = target.component.name
        return inspectionSystem:ApplyHighlightEffect(target.component:GetEntity(), effect)
    end

    if IsDefined(target.nodeInstance) then
        return inspectionSystem:ApplyHighlightEffect(target.nodeInstance, effect)
    end

    return false
end

function highlighting.disable()
    if highlighting.target then
        highlighting.applyEffect(highlighting.target, highlighting.profile, false, true)

        highlighting.target = nil
        highlighting.profile = nil
        highlighting.projections = {}
    end
end

function highlighting.update()
    if not highlighting.pending then
        highlighting.disable()
        return
    end

    highlighting.changed = true

    if highlighting.target then
        if highlighting.target.hash ~= highlighting.pending.hash then
            highlighting.disable()
        else
            highlighting.changed = false
        end
    end

    highlighting.target = highlighting.pending
    highlighting.pending = nil

    highlighting.profile = highlighting.resolveProfile(highlighting.target)
    highlighting.projections = {}

    if not highlighting.profile then
        return
    end

    local showOrigin = false
    if highlighting.target.position and not highlighting.target.position:IsXYZZero() then
        if userState.markerMode == MarkerMode.Always then
            showOrigin = true
        elseif userState.markerMode == MarkerMode.ForStaticTargets then
            showOrigin = not highlighting.target.isEntity
        elseif userState.markerMode == MarkerMode.ForInvisibleTargets then
            showOrigin = not highlighting.target.isEntity and not highlighting.target.isVisibleNode
        end
    end

    local showBoundingBox = false
    if highlighting.target.boundingBox and highlighting.target.boundingBox:GetRange() > 0 then
        if userState.boundingBoxMode == BoundingBoxMode.Always then
            showBoundingBox = true
        elseif userState.boundingBoxMode == BoundingBoxMode.ForStaticTargets then
            showBoundingBox = not highlighting.target.isEntity
        elseif userState.boundingBoxMode == BoundingBoxMode.ForInvisibleTargets then
            showBoundingBox = not highlighting.target.isEntity and not highlighting.target.isVisibleNode
        end
    end

    if showOrigin or showBoundingBox then
        highlighting.projections[highlighting.target.hash] = {
            target = highlighting.target,
            profile = highlighting.profile,
            showOrigin = showOrigin,
            showOriginDistance = userState.showMarkerDistance,
            showBoundingBox = showBoundingBox,
            showBoundingBoxDistances = userState.showBoundingBoxDistances,
        }
    end

    if userState.outlineMode == OutlineMode.ForSupportedTargets then
        highlighting.applyEffect(highlighting.target, highlighting.profile, true, highlighting.changed)
    end
end

function highlighting.setTarget(target)
    if target and target.hash then
        highlighting.pending = target
    else
        highlighting.pending = nil
    end
end

-- Resolving --

local resolving = {
    nodeGroupMapping = require(modulePath .. '/data/target-group-mapping'),
}

function resolving.resolveComponents(entity)
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

        --if IsDefined(component.filterData) then
        --    data.collisionPreset = component.filterData.preset.value
        --end

        local description = { data.componentType, data.componentName }
        data.description = table.concat(description, ' | ')

        data.hash = RedHotTools.GetObjectHash(component)
        data.component = Ref.Weak(component)

        table.insert(components, data)
    end

    table.sort(components, function(a, b)
        if a.componentType == b.componentType then
            return a.componentName < b.componentName
        end
        return a.componentType < b.componentType
    end)

    return components
end

function resolving.resolveVisualTags(entity, owner)
    local visualTags = {}

    for _, tag in ipairs(RedHotTools.GetEntityVisualTags(entity)) do
        table.insert(visualTags, { value = tag.value })
    end

    if entity:IsA('gameItemObject') then
        for _, tag in ipairs(transactionSystem:GetVisualTagsByItemID(entity:GetItemID(), owner)) do
            table.insert(visualTags, { value = tag.value })
        end
    end

    return visualTags
end

function resolving.resolveAttachments(entity)
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
        local itemData = entity:GetItemData()
        if IsDefined(itemData) then
            for _, slotID in ipairs(itemData:GetUsedSlotsOnItem()) do
                table.insert(slotIDs, slotID)
            end
            for _, slotID in ipairs(itemData:GetEmptySlotsOnItem()) do
                table.insert(slotIDs, slotID)
            end
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

            data.components = resolving.resolveComponents(item)
            data.attachments = resolving.resolveAttachments(item)
            data.visualTags = resolving.resolveVisualTags(item, entity)

            data.numComponents = #data.components
            data.numAttachments = #data.attachments
            data.numVisualTags = #data.visualTags

            data.hasComponents = data.numComponents > 0
            data.hasAttachments = data.numAttachments > 0
            data.hasVisualTags = data.numVisualTags > 0

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

function resolving.fillTargetEntityData(target, data)
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
                local vendorID = TweakDB:GetFlat(TweakDBID.new(recordID, '.vendorID'))
                if TDBID.IsValid(vendorID) then
                    data.vendorID = vendorID.value
                end
            end

            local success, items = transactionSystem:GetItemList(entity)
            if success then
                for _, item in ipairs(items) do
                    local itemID = item:GetID().id.value
                    if isNotEmpty(itemID) then
                        table.insert(data.inventory, { value = itemID })
                    end
                end
                table.sort(data.inventory, function(a, b)
                    return a.value < b.value
                end)
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

        data.components = resolving.resolveComponents(entity)
        data.attachments = resolving.resolveAttachments(entity)
        data.visualTags = resolving.resolveVisualTags(entity)

        data.numInventory = #data.inventory
        data.numComponents = #data.components
        data.numAttachments = #data.attachments
        data.numVisualTags = #data.visualTags

        data.hasInventory = data.numInventory > 0
        data.hasComponents = data.numComponents > 0
        data.hasAttachments = data.numAttachments > 0
        data.hasVisualTags = data.numVisualTags > 0

        if IsDefined(target.component) then
            data.componentName = target.component.name.value
            data.componentType = target.component:GetClassName().value
        end
    end

    data.entity = target.entity
    data.component = target.component
    data.isEntity = IsDefined(data.entity)
end

function resolving.fillTargetCommunityData(target, data)
    if IsDefined(target.entity) then
        local communityData = inspectionSystem:ResolveCommunityEntryDataFromEntityID(target.entity:GetEntityID().hash)
        if communityData.sectorHash ~= 0 then
            data.communityRegistryPath = RedHotTools.GetResourcePath(communityData.sectorHash)
            data.communityRegistryIndex = communityData.registryIndex
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

function resolving.fillTargetNodeData(target, data)
    local sectorData
    if IsDefined(target.nodeInstance) then
        sectorData = inspectionSystem:ResolveSectorDataFromNodeInstance(target.nodeInstance)
        --data.nodeEnabled = inspectionSystem:GetNodeVisibility(target.nodeInstance)
    elseif isNotEmpty(target.nodeID) then
        sectorData = inspectionSystem:ResolveSectorDataFromNodeID(target.nodeID)
    end
    if sectorData and sectorData.sectorHash ~= 0 then
        data.sectorPath = RedHotTools.GetResourcePath(sectorData.sectorHash)
        data.instanceIndex = sectorData.instanceIndex
        data.instanceCount = sectorData.instanceCount
        data.nodeIndex = sectorData.nodeIndex
        data.nodeCount = sectorData.nodeCount
        data.innerIndex = sectorData.innerIndex
        data.innerCount = sectorData.innerCount
        data.nodeType = sectorData.nodeType.value
        data.nodeID = sectorData.nodeID
        data.nodeProxyID = sectorData.proxyID
        data.nodeParentID = sectorData.parentID
        data.debugName = sectorData.debugName
        data.sourcePrefabHash = sectorData.sourcePrefabHash
        data.interior = sectorData.interior
    end

    if IsDefined(target.nodeDefinition) then
        local node = target.nodeDefinition
        data.nodeType = RedHotTools.GetTypeName(node).value

        if RedHotTools.IsInstanceOf(node, 'worldMeshNode')
        or RedHotTools.IsInstanceOf(node, 'worldBendedMeshNode')
        or RedHotTools.IsInstanceOf(node, 'worldFoliageNode')
        or RedHotTools.IsInstanceOf(node, 'worldPhysicalDestructionNode') then
            data.meshPath = RedHotTools.GetResourcePath(node.mesh.hash)
            data.meshAppearance = node.meshAppearance.value
        end

        if RedHotTools.IsInstanceOf(node, 'worldCookedMeshNode')
        or RedHotTools.IsInstanceOf(node, 'worldCookedBendedMeshNode') then
            if data.innerCount then
                local innerNode = node:GetInnerNode(data.innerIndex)
                data.meshPath = RedHotTools.GetResourcePath(innerNode.mesh.hash)
                data.meshAppearance = innerNode.meshAppearance.value
            end
        end

        if RedHotTools.IsInstanceOf(node, 'worldInstancedMeshNode') then
            if data.innerIndex and data.innerIndex < data.innerCount then
                local innerNode = node.cookedInstances[data.innerIndex + 1]
                data.meshPath = RedHotTools.GetResourcePath(innerNode.mesh.hash)
                data.meshAppearance = innerNode.meshAppearance.value
            end
        end

        if RedHotTools.IsInstanceOf(node, 'worldTerrainMeshNode') then
            data.meshPath = RedHotTools.GetResourcePath(node.meshRef.hash)
        end

        if RedHotTools.IsInstanceOf(node, 'worldStaticDecalNode') then
            data.materialPath = RedHotTools.GetResourcePath(node.material.hash)
        end

        if RedHotTools.IsInstanceOf(node, 'worldCookedStaticDecalNode') then
            if data.innerCount then
                local innerNode = node:GetInnerNode(data.innerIndex)
                data.materialPath = RedHotTools.GetResourcePath(innerNode.material.hash)
            end
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

        if RedHotTools.IsInstanceOf(node, 'worldAISpotNode') and node.spot and node.spot.resource then
            data.workspotPath = RedHotTools.GetResourcePath(node.spot.resource.hash)
        end

        if RedHotTools.IsInstanceOf(node, 'worldFoliageNode') then
            data.foliagePath = RedHotTools.GetResourcePath(node.foliageResource.hash)
        end

        if RedHotTools.IsInstanceOf(node, 'worldStaticParticleNode') then
            data.particlePath = RedHotTools.GetResourcePath(node.particleSystem.hash)
        end
    end

    if isNotEmpty(data.nodeID) then
        data.nodeRef = inspectionSystem:ResolveNodeRefFromNodeHash(data.nodeID)
    elseif isNotEmpty(target.nodeID) then
        data.nodeRef = inspectionSystem:ResolveNodeRefFromNodeHash(target.nodeID)
    end

    if isNotEmpty(data.nodeProxyID) then
        data.nodeProxyRef = inspectionSystem:ResolveNodeRefFromNodeHash(data.nodeProxyID)
    end

    if isNotEmpty(data.nodeParentID) then
        data.nodeParentRef = inspectionSystem:ResolveNodeRefFromNodeHash(data.nodeParentID)
        --if isNotEmpty(data.nodeParentRef) then
        --    data.nodeParentInstance = inspectionSystem:FindStreamedNode(data.nodeParentID).nodeInstance
        --end
    end

    data.nodeDefinition = target.nodeDefinition
    data.nodeInstance = target.nodeInstance

    data.isNode = IsDefined(data.nodeInstance) or IsDefined(data.nodeDefinition) or isNotEmpty(data.nodeID)
    data.isCookedNode =  data.isNode and RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldCookedNode')
    data.isMeshNode = data.isNode and (RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldMeshNode') or
        RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldCookedMeshNode') or
        RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldInstancedMeshNode'))
    data.isFoliageNode = data.isNode and RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldFoliageNode')
    data.isCollisionNode = data.isNode and (RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldCollisionNode') or
        RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldCookedCollisionNode'))
    data.isOccluderNode = data.isNode and (RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldStaticOccluderMeshNode') or
        RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldInstancedOccluderNode'))
    data.isVisibleNode = data.isNode and (isNotEmpty(data.meshPath) or isNotEmpty(data.materialPath)
        or isNotEmpty(data.templatePath) or isNotEmpty(data.particlePath)
        or RedHotTools.IsInstanceOf(data.nodeDefinition, 'worldStaticLightNode'))

    if data.nodeType == 'worldCompiledCommunityAreaNode_Streamable' then
        data.interior = nil
    elseif target.interior then
        data.interior = true
    end

    if isNotEmpty(data.nodeType) then
        data.nodeGroup = resolving.nodeGroupMapping[data.nodeType]
    end
end

function resolving.fillRuntimeGeometryData(data)
    if IsDefined(data.entity) then
        local geometry = (data.entity:IsA('gameObject') and (data.entity:IsNPC() or data.entity:IsContainer())) and inspectionSystem:GetPhysicsObjectGeometry(data.entity) or inspectionSystem:GetVisualObjectGeometry(data.entity)
        data.position = geometry.position
        data.orientation = geometry.orientation
        data.boundingBox = geometry.boundingBox
    elseif data.physicsProxyID then
        local geometry = inspectionSystem:GetPhysicsProxyGeometry(data.physicsProxyID, data.physicsActorIndex, data.physicsShapeIndex or -1)
        data.position = geometry.position
        data.orientation = geometry.orientation
        data.boundingBox = geometry.boundingBox
        if IsDefined(data.nodeInstance) then
            data.nodePosition = data.position
            data.nodeOrientation = data.orientation
        end
    end
end

function resolving.fillTargetGeomertyData(target, data)
    data.collision = target.collision
    data.distance = target.distance
    data.position = target.position
    data.orientation = target.orientation
    data.boundingBox = target.boundingBox

    if IsDefined(data.nodeInstance) then
        data.nodePosition = data.position
        data.nodeOrientation = data.orientation

        local geometry = inspectionSystem:GetStreamedNodeGeometry(data.nodeInstance)
        if not Vector4.IsXYZZero(geometry.position) then
            data.nodePosition = geometry.position
            data.nodeOrientation = geometry.orientation
            data.nodeScale = geometry.scale
        end
    end

    if IsDefined(data.entity) then
        data.entityPosition = data.entity:GetWorldPosition()
        data.entityOrientation = data.entity:GetWorldOrientation()
    elseif target.proxyID then
        data.physicsProxyID = target.proxyID
        data.physicsActorIndex = target.actorIndex or 0
        data.physicsActorOffset = target.actorOffset or 0
        data.physicsActorCount = target.actorCount or 0
        if data.isCollisionNode and userState.collisionGranularity == CollisionGranularity.Shape then
            data.physicsShapeIndex = target.shapeIndex or 0
            data.physicsShapeCount = target.shapeCount or 0
        else
            data.physicsShapeIndex = -1
            data.physicsShapeCount = 0
        end
        data.actorIndex = data.physicsActorIndex + data.physicsActorOffset
        data.actorCount = data.physicsActorCount
        data.shapeIndex = data.physicsShapeIndex
        data.shapeCount = data.physicsShapeCount
    elseif target.actorCount and target.actorCount > 1 then
        data.actorIndex = target.actorIndex or 0
        data.actorCount = target.actorCount or 0
    end

    resolving.fillRuntimeGeometryData(data)

    if data.boundingBox and data.boundingBox:GetRange() <= 0 then
        data.boundingBox = nil
    end

    if not data.position then
        data.position = data.nodePosition or data.entityPosition
    end
end

function resolving.fillTargetDescription(_, data)
    if isNotEmpty(data.nodeType) then
        local description = { data.nodeType }
        if isNotEmpty(data.meshPath) then
            local resourceName = data.meshPath:match('\\([^\\]+)$')
            table.insert(description, resourceName)
        elseif isNotEmpty(data.materialPath) then
            local resourceName = data.materialPath:match('\\([^\\]+)$')
            table.insert(description, resourceName)
        elseif isNotEmpty(data.particlePath) then
            local resourceName = data.particlePath:match('\\([^\\]+)$')
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
end

function resolving.fillTargetHash(target, data)
    if isNotEmpty(target.hash) then
        data.hash = target.hash
    elseif IsDefined(target.entity) then
        data.hash = RedHotTools.GetObjectHash(target.entity)
    elseif IsDefined(target.nodeInstance) then
        data.hash = RedHotTools.GetObjectHash(target.nodeInstance)
    elseif IsDefined(target.nodeDefinition) then
        data.hash = RedHotTools.GetObjectHash(target.nodeDefinition)
    end
end

function resolving.expandTarget(target)
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

function resolving.resolveTargetData(target)
    resolving.expandTarget(target)

    local result = {}
    resolving.fillTargetEntityData(target, result)
    resolving.fillTargetCommunityData(target, result)
    resolving.fillTargetNodeData(target, result)
    resolving.fillTargetGeomertyData(target, result)
    resolving.fillTargetDescription(target, result)
    resolving.fillTargetHash(target, result)

    return result
end

function resolving.updateTargetData(target, data)
    data.distance = target.distance

    if IsDefined(target.entity) then
        data.entityPosition = data.entity:GetWorldPosition()
        data.entityOrientation = data.entity:GetWorldOrientation()
    elseif target.proxyID then
        data.physicsProxyID = target.proxyID
        data.physicsActorIndex = target.actorIndex or 0
        data.physicsActorOffset = target.actorOffset or 0
        data.physicsActorCount = target.actorCount or 0
        if data.isCollisionNode and userState.collisionGranularity == CollisionGranularity.Shape then
            data.physicsShapeIndex = target.shapeIndex or 0
            data.physicsShapeCount = target.shapeCount or 0
        else
            data.physicsShapeIndex = -1
            data.physicsShapeCount = 0
        end
        data.actorIndex = data.physicsActorIndex + data.physicsActorOffset
        data.actorCount = data.physicsActorCount
        data.shapeIndex = data.physicsShapeIndex
        data.shapeCount = data.physicsShapeCount
    elseif target.actorCount and target.actorCount > 1 then
        data.actorIndex = target.actorIndex or 0
        data.actorCount = target.actorCount or 0
        data.position = target.position
        data.orientation = target.orientation
        data.boundingBox = target.boundingBox
    end

    if IsDefined(target.component) then
        data.componentName = target.component.name.value
        data.componentType = target.component:GetClassName().value
    end
end

function resolving.updateGeometryData(data)
    resolving.fillRuntimeGeometryData(data)
end

-- Filtering --

local filtering = {
    partialMatchFields = {
        'value',
        'nodeType',
        'nodeRef',
        'nodeProxyRef',
        'nodeParentRef',
        'sectorPath',
        'debugName',
        'componentType',
        'componentName',
        'recordID',
        'triggerNotifiers',
        'meshPath',
        'appearanceName',
        'materialPath',
        'effectPath',
        'templatePath',
        'slotID',
        'itemID',
        'itemType',
    },
    exactMatchFields = {
        'instanceIndex',
    },
}

function filtering.buildQuery(term)
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

function filtering.filterTargetData(target, query)
    if isEmpty(query) then
        return true
    end

    for _, field in ipairs(filtering.exactMatchFields) do
        if isNotEmpty(target[field]) then
            local value = tostring(target[field]):upper()
            if value == query.exact then
                return true
            end
        end
    end

    for _, field in ipairs(filtering.partialMatchFields) do
        if type(target[field]) == 'table' then
            for _, item in ipairs(target[field]) do
                local value = tostring(item):upper()
                if value:find(query.exact, 1, true) or value:find(query.wildcard) then
                    return true
                end
            end
        elseif isNotEmpty(target[field]) then
            local value = tostring(target[field]):upper()
            if value:find(query.exact, 1, true) or value:find(query.wildcard) then
                return true
            end
        end
    end

    return false
end

function filtering.filterTargetDataList(targets, query)
    local numFiltered = 0

    for _, target in ipairs(targets) do
        target.filtered = filtering.filterTargetData(target, query)

        if target.filtered then
            numFiltered = numFiltered + 1
        end
    end

    return numFiltered
end

function filtering.filterTargetExtras(target, query)
    if target.hasComponents then
        target.numFilteredComponents = filtering.filterTargetDataList(target.components, query)
    end

    if target.hasAttachments then
        target.numFilteredAttachments = filtering.filterTargetDataList(target.attachments, query)

        for _, attachment in ipairs(target.attachments) do
            if isNotEmpty(attachment.itemID) then
                filtering.filterTargetExtras(attachment, query)
            end
        end
    end

    if target.hasInventory then
        target.numFilteredInventory = filtering.filterTargetDataList(target.inventory, query)
    end

    if target.hasVisualTags then
        target.numFilteredVisualTags = filtering.filterTargetDataList(target.visualTags, query)
    end
end

-- Control --

local control = {
    lastTarget = nil,
}

function control.canToggleState(target)
    return target and IsDefined(target.nodeInstance) and target.isVisibleNode
end

function control.toggleState(target)
    if not target or not control.canToggleState(target) then
        target = control.lastTarget
        control.lastTarget = nil
    end

    if target then
        if IsDefined(target.parentInstance) then
            inspectionSystem:ToggleNodeVisibility(target.parentInstance)
            control.lastTarget = target
        elseif IsDefined(target.nodeInstance) then
            inspectionSystem:ToggleNodeVisibility(target.nodeInstance)
            control.lastTarget = target
        end
    end
end

-- Inspector --

local inspector = {
    targets = nil,
    results = nil,
    active = nil,
    filter = {
        term = '',
        target = nil,
    },
}

function inspector.compareTargets(setA, setB, sorted)
    local sizeA = #setA
    local sizeB = #setB
    local size = math.min(sizeA, sizeB)

    local hashesA = {}
    local hashesB = {}

    for i = 1,size do
        table.insert(hashesA, setA[i].hash)
        table.insert(hashesB, setB[i].hash)
    end

    if sorted then
        table.sort(hashesA)
        table.sort(hashesB)
    end

    for i = 1,size do
        if hashesA[i] ~= hashesB[i] then
            return false, i
        end
    end

    return sizeA == sizeB, size
end

function inspector.updateTargets(results, targets)
    for _, target in ipairs(targets) do
        for _, result in ipairs(results) do
            if result.hash == target.hash then
                resolving.updateTargetData(target, result)
                break
            end
        end
    end
end

function inspector.updateTargetsFromLookAt(targets)
    if not targets or #targets == 0 then
        inspector.targets = {}
        inspector.results = {}
        inspector.active = nil
        return
    end

    for i = #targets, 1, -1 do
        if IsDefined(targets[i].nodeDefinition) then
            if targets[i].distance < 0.1 and not targets[i].interior then
                table.remove(targets, i)
            elseif
                RedHotTools.IsInstanceOf(targets[i].nodeDefinition, 'worldTerrainMeshNode') or
                RedHotTools.IsInstanceOf(targets[i].nodeDefinition, 'worldTerrainCollisionNode') or
                RedHotTools.IsInstanceOf(targets[i].nodeDefinition, 'worldTerrainProxyMeshNode') or
                RedHotTools.IsInstanceOf(targets[i].nodeDefinition, 'worldCookedTerrainProxyMeshNode')
            then
                table.remove(targets, i)
            end
        end
    end

    while #targets > userState.maxTargets do
        table.remove(targets)
    end

    if not targets or #targets == 0 then
        inspector.targets = {}
        inspector.results = {}
        inspector.active = nil
        return
    end

    local sameTargets = false
    local sameUpToIndex = false
    local isStaticMode = userState.targetingMode == TargetingMode.StaticBounds
    if inspector.targets then
        sameTargets, sameUpToIndex = inspector.compareTargets(inspector.targets, targets, isStaticMode)
        if sameTargets then
            inspector.updateTargets(inspector.results, targets)
            return
        end
    end

    local results = {}
    for _, target in ipairs(targets) do
        local result = resolving.resolveTargetData(target)
        if result then
            table.insert(results, result)
        end
    end

    local active = 1
    if inspector.active and #inspector.results > 1 and sameUpToIndex > 0 then
        if inspector.active <= sameUpToIndex and inspector.results[inspector.active].hash == targets[inspector.active].hash then
             active = inspector.active
        else
            local priority = 0
             local previous = inspector.results[inspector.active]
             for index, result in ipairs(results) do
                 if result.hash == previous.hash then
                    if isStaticMode then
                        active = index
                        break
                    elseif result.collision.dynamic and not results[active].collision.dynamic then
                        active = index
                        break
                    end
                 elseif active ~= index then
                    if isStaticMode then
                        if priority < 3 then
                            if result.meshPath and result.meshPath == previous.meshPath
                            or result.materialPath and result.materialPath == previous.materialPath
                            or result.particlePath and result.particlePath == previous.particlePath then
                                if math.abs(result.distance - previous.distance) <= 10 then
                                    active = index
                                    priority = 3
                                end
                            end
                        end
                    end
                    if priority < 1 then
                        if result.nodeType and result.nodeType == previous.nodeType and result.interior == previous.interior then
                            if math.abs(result.distance - previous.distance) <= 0.1 then
                                active = index
                                priority = 1
                            end
                        end
                    end
                 end
             end
        end
    end

    inspector.targets = targets
    inspector.results = results
    inspector.active = active
end

function inspector.selectResult(index)
    inspector.active = index
    if inspector.active < 1 then
        inspector.active = 1
    elseif inspector.active > #inspector.results then
        inspector.active = #inspector.results
    end
end

function inspector.cycleNext()
    if inspector.active and not targeting.paused then
        inspector.active = inspector.active + 1
        if inspector.active > #inspector.results then
            inspector.active = userState.cycleInspectorResults and 1 or #inspector.results
        end
    end
end

function inspector.cyclePrev()
    if inspector.active and not targeting.paused then
        inspector.active = inspector.active - 1
        if inspector.active < 1 then
            inspector.active = userState.cycleInspectorResults and #inspector.results or 1
        end
    end
end

function inspector.filterTarget(filter)
    local selected = inspector.active and inspector.results[inspector.active] or nil

    if inspector.filter.term == filter and inspector.filter.target == selected then
        return
    end

    if selected then
        filtering.filterTargetExtras(selected, filtering.buildQuery(filter))
    end

    inspector.filter.term = filter
    inspector.filter.target = selected
end

function inspector.update(filter)
    inspector.updateTargetsFromLookAt(targeting.getLookAtTargets())
    inspector.filterTarget(filter)

    if userState.highlightInspectorResult and inspector.active and not targeting.paused then
        highlighting.setTarget(inspector.results[inspector.active])
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

function scanner.requestScan()
    scanner.requested = true
end

function scanner.selectResult(index)
    scanner.hovered = index
end

function scanner.unselectResult()
    scanner.hovered = nil
end

function scanner.updateTargets()
    if not scanner.requested then
        return
    end

    scanner.requested = false

    local results = {}

    for _, target in ipairs(inspectionSystem:GetStreamedNodesInFrustum()) do
        local result = resolving.resolveTargetData(target)
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

function scanner.filterByDistance(target, distance)
    return isEmpty(distance) or target.distance <= distance
end

function scanner.filterByGroup(target, group)
    return isEmpty(group) or target.nodeGroup == group
end

function scanner.filterByQuery(target, query)
    return isEmpty(query) or filtering.filterTargetData(target, query)
end

function scanner.filterTargets(maxDistance, group, term)
    if scanner.group == group and scanner.term == term and scanner.distance == maxDistance then
        return
    end

    local filtered = {}
    local query = filtering.buildQuery(term)

    for _, result in ipairs(scanner.results) do
        if scanner.filterByDistance(result, maxDistance)
        and scanner.filterByGroup(result, group)
        and scanner.filterByQuery(result, query) then
            table.insert(filtered, result)
        end
    end

    scanner.distance = maxDistance
    scanner.group = group
    scanner.term = term
    scanner.filtered = filtered
end

function scanner.update(distance, group, filter)
    scanner.updateTargets()
    scanner.filterTargets(distance, group, filter)

    if userState.highlightScannerResult and scanner.hovered then
        highlighting.setTarget(scanner.results[scanner.hovered])
    end
end

-- Lookup --

local lookup = {
    query = nil,
    result = nil,
    empty = true,
}

function lookup.parseHash(lookupQuery)
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

function lookup.lookupTarget(lookupQuery)
    if isEmpty(lookupQuery) then
        lookup.query = nil
        lookup.result = nil
        return
    end

    if lookup.query == lookupQuery then
        return
    end

    local target = {}

    local lookupHash = lookup.parseHash(lookupQuery)
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

    local data = resolving.resolveTargetData(target) or {}

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

function lookup.update(lookupQuery)
    lookup.lookupTarget(lookupQuery)

    if userState.highlightLookupResult then
        highlighting.setTarget(lookup.result)
    end
end

-- Watcher --

local watcher = {
    targets = {},
    results = {},
    numTargets = 0,
    filter = {
        term = '',
    },
}

function watcher.getEntityKey(entity)
    return tostring(entity:GetEntityID().hash)
end

function watcher.watchEntity(entity)
    if not IsDefined(entity) then
        return
    end

    local key = watcher.getEntityKey(entity)
    local target = { entity = Ref.Weak(entity) }

    watcher.targets[key] = target
    watcher.results[key] = resolving.resolveTargetData(target)
    watcher.numTargets = watcher.numTargets + 1
end

function watcher.forgetEntity(entity)
    if not IsDefined(entity) then
        return
    end

    local key = watcher.getEntityKey(entity)

    if watcher.targets[key] then
        watcher.targets[key] = nil
        watcher.results[key] = nil
        watcher.numTargets = watcher.numTargets - 1

        collectgarbage()
    end
end

function watcher.canWatchTarget(target)
    return target and IsDefined(target.entity)
end

function watcher.isWatchedTarget(target)
    return target and IsDefined(target.entity) and watcher.targets[watcher.getEntityKey(target.entity)] ~= nil
end

function watcher.watchTarget(target)
    watcher.watchEntity(target.entity)
end

function watcher.forgetTarget(target)
    watcher.forgetEntity(target.entity)
end

function watcher.initialize()
    watcher.watchEntity(GetPlayer())
    watcher.watchEntity(GetMountedVehicle(GetPlayer()))

    ObserveAfter('PlayerPuppet', 'OnGameAttached', function(this)
        watcher.watchEntity(this)
    end)

    ObserveAfter('PlayerPuppet', 'OnDetach', function(this)
        watcher.forgetEntity(this)
    end)

    ObserveBefore('gameuiPuppetPreviewGameController', 'OnPreviewInitialized', function(this)
        watcher.watchEntity(this:GetGamePuppet())
    end)

    ObserveBefore('gameuiPuppetPreviewGameController', 'OnUninitialize', function(this)
        if this:IsA('gameuiPuppetPreviewGameController') then
            watcher.forgetEntity(this:GetGamePuppet())
        end
    end)

    ObserveAfter('PhotoModePlayerEntityComponent', 'SetupInventory', function(this)
        watcher.watchEntity(this.fakePuppet)
    end)

    ObserveBefore('PhotoModePlayerEntityComponent', 'ClearInventory', function(this)
        watcher.forgetEntity(this.fakePuppet)
    end)

    ObserveAfter('vehicleBaseObject', 'OnVehicleFinishedMounting', function(this, event)
        if this:IsPlayerVehicle() then
            if event.character:IsPlayer() and event.isMounting then
                watcher.watchEntity(this)
            else
                watcher.forgetEntity(this)
            end
        end
    end)
end

function watcher.update(filter)
    local query = filtering.buildQuery(filter)

    for key, target in pairs(watcher.targets) do
        local result = resolving.resolveTargetData(target)
        filtering.filterTargetExtras(result, query)

        watcher.results[key] = result
    end

    watcher.filter.term = filter
end

-- GUI --

local viewState = {
    isFirstOpen = true,
    isConsoleOpen = false,
    isWindowOpen = true,
    isWindowExpanded = true,
    lookupQuery = '',
    inspectorFilter = '',
    inspectorFilterActive = nil,
    watcherFilter = '',
}

local viewStyle = {
    labelTextColor = 0xFFA5A19B,
    mutedTextColor = 0xFFA5A19B,
    hintTextColor = 0x66FFFFFF,
    dangerTextColor = 0xFF6666FF,
    disabledButtonColor = 0xFF4F4F4F,
    groupCaptionSize = 0.8,
}

local view = {
    maxInputLen = 512,
    currentWindowHeightMode = nil,
    meshAppearanceCache = {},
}

function view.buildMappingOptions(mapping, first)
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

function view.initializeData()
    view.targetingModeOptions = ImGuiEx.BuildComboOptions(TargetingMode.values, true)
    view.collisionGranularityOptions = ImGuiEx.BuildComboOptions(CollisionGranularity.values, true)
    view.outlineModeOptions = ImGuiEx.BuildComboOptions(OutlineMode.values)
    view.markerModeOptions = ImGuiEx.BuildComboOptions(MarkerMode.values)
    view.boundingBoxModeOptions = ImGuiEx.BuildComboOptions(BoundingBoxMode.values)
    view.windowSnappingOptions = ImGuiEx.BuildComboOptions(WindowSnapping.values, true)
    view.nodeGroupOptions = view.buildMappingOptions(resolving.nodeGroupMapping, 'All')

    if not view.nodeGroupOptions[userState.scannerGroup] then
        userState.scannerGroup = ''
    end
end

function view.initializeStyle()
    if not viewStyle.fontSize then
        viewStyle.fontSize = ImGui.GetFontSize()
        viewStyle.viewScale = viewStyle.fontSize / 13

        viewStyle.windowPaddingX = 8 * viewStyle.viewScale
        viewStyle.windowPaddingY = viewStyle.windowPaddingX
        viewStyle.windowMinWidth = 400 * viewStyle.viewScale + viewStyle.windowPaddingX * 2 - 1
        viewStyle.windowMinHeight = 445 * viewStyle.viewScale
        viewStyle.windowMaxWidth = 2147483647
        viewStyle.windowMaxHeight = 2147483647
        viewStyle.windowMarginX = 4 * viewStyle.viewScale
        viewStyle.windowMarginY = 4 * viewStyle.viewScale

        viewStyle.mainWindowFlags = ImGuiWindowFlags.NoScrollbar
            + ImGuiWindowFlags.NoScrollWithMouse
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

        viewStyle.treeNodeArrowWidth = viewStyle.fontSize + ImGui.GetStyle().ItemSpacing.x / 2
        viewStyle.treeNodePaddingX = 4 * viewStyle.viewScale
        viewStyle.treeNodePaddingY = 0

        viewStyle.componentToggleWidth = ImGui.GetFrameHeight()
        viewStyle.componentToggleMarginX = 4 * viewStyle.viewScale

        viewStyle.inspectorTargetWidth = ImGui.CalcTextSize(' 00 ') + ImGui.GetStyle().FramePadding.x * 2 - 3
        viewStyle.inspectorFilterWidth = 100 * viewStyle.viewScale
        viewStyle.inspectorFilterHeight = ImGui.GetFrameHeight()
        viewStyle.inspectorFilterBg = ImGui.GetColorU32(ImGuiCol.WindowBg, 1)

        viewStyle.scannerFilterWidth = 95 * viewStyle.viewScale
        viewStyle.scannerGroupWidth = 75 * viewStyle.viewScale
        viewStyle.scannerDistanceWidth = 85 * viewStyle.viewScale
        viewStyle.scannerStatsWidth = ImGui.CalcTextSize('0000 / 0000') * viewStyle.viewScale

        viewStyle.settingsShortInputWidth = 80 * viewStyle.viewScale
        viewStyle.settingsMiddleInputWidth = 90 * viewStyle.viewScale
        viewStyle.settingsShortComboRowWidth = 160 * viewStyle.viewScale
        viewStyle.settingsMiddleComboRowWidth = 210 * viewStyle.viewScale
        viewStyle.settingsLongComboRowWidth = 240 * viewStyle.viewScale

        viewStyle.defaultTextColor = ImGui.GetColorU32(ImGuiCol.Text, 1)
        viewStyle.defaultFrameBg = ImGui.GetColorU32(ImGuiCol.FrameBg, 1)
        viewStyle.defaultFramePaddingX = ImGui.GetStyle().FramePadding.x
        viewStyle.defaultFramePaddingY = ImGui.GetStyle().FramePadding.y
    end
end

-- GUI :: Actions --

function view.getTargetActions(target, isInputMode)
    local actions = {}

    if isInputMode then
        if watcher.canWatchTarget(target) then
            if watcher.isWatchedTarget(target) then
                table.insert(actions, {
                    type = 'button',
                    label = 'Unwatch entity',
                    callback = watcher.forgetTarget,
                    inline = true,
                })
            else
                table.insert(actions, {
                    type = 'button',
                    label = 'Watch entity',
                    callback = watcher.watchTarget,
                    inline = true,
                })
            end
        end
        if control.canToggleState(target) then
            table.insert(actions, {
                type = 'button',
                label = 'Toggle visibility',
                callback = control.toggleState,
                inline = true,
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
                    if action.inline == nil then
                        action.inline = true
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

function view.isValidArrayField(data, field)
    return type(data[field.name]) == 'table' and #data[field.name] > 0
end

function view.formatArrayField(data, field)
    return table.concat(data[field.name], '\n')
end

function view.isValidPosition(data, field)
    local vec = data[field.name]
    return vec and (vec.x ~= 0 or vec.y ~= 0 or vec.z ~= 0)
end

function view.formatPosition(data, field)
    local vec = data[field.name]
    return ('%.3f, %.3f, %.3f, %.3f'):format(vec.x, vec.y, vec.z, vec.w):gsub('%.000', '.0')
end

function view.isValidOrientation(data, field)
    local quat = data[field.name]
    return quat and (quat.i ~= 0 or quat.j ~= 0 or quat.k ~= 0 or quat.r ~= 1)
end

function view.formatOrientation(data, field)
    local quat = data[field.name]
    return ('%.3f, %.3f, %.3f, %.3f'):format(quat.i, quat.j, quat.k, quat.r):gsub('%.000', '.0')
end

function view.isValidScale(data, field)
    local vec = data[field.name]
    return vec and (vec.x ~= 1 or vec.y ~= 1 or vec.z ~= 1)
end

function view.formatScale(data, field)
    local vec = data[field.name]
    return ('%.3f, %.3f, %.3f'):format(vec.x, vec.y, vec.z):gsub('%.000', '.0')
end

function view.formatDistance(data)
    return ('%.1fm'):format(type(data) == 'table' and data.distance or data)
end

function view.isValidChunkMask(data)
    return type(data.chunkMask) == 'cdata' or type(data.chunkMask) == 'number'
end

function view.getBit(value, index)
    return bit32.band(bit32.rshift(value, index), 1) ~= 0
end

function view.setBit(value, index, state)
    local bit = bit32.lshift(1ULL, index)
    return state and bit32.bor(value, bit) or bit32.band(value, bit32.bnot(bit))
end

function view.drawBitEditor(data, field)
    ImGui.SameLine()

    local startX = ImGui.GetCursorPosX()
    local bitWidth = ImGui.CalcTextSize('0') + 2
    local bitSpacing = 1
    local groupWidth = 8 * bitWidth + 7 * bitSpacing
    local groupSpacing = 7

    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 1, 1)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)

    for row = 0, 1 do
        if row > 0 then
            ImGui.SetCursorPosX(startX)
        end

        for group = 0, 3 do
            for bit = 0, 7 do
                local index = row * 32 + group * 8 + bit

                if index % 32 ~= 0 then
                    ImGui.SameLine()
                    ImGui.SetCursorPosX(startX + group * (groupWidth + groupSpacing) + bit * (bitWidth + bitSpacing))
                end

                local isSet = view.getBit(data[field.name], index)

                ImGui.PushID(index)

                ImGui.PushStyleColor(ImGuiCol.Button, 0)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0)
                ImGui.PushStyleColor(ImGuiCol.Text, isSet and viewStyle.defaultTextColor or viewStyle.mutedTextColor)

                if ImGui.Button(isSet and '1' or '0', bitWidth, 0) then
                    data[field.name] = view.setBit(data[field.name], index, not isSet)

                    if IsDefined(data.component) then
                        data.component[field.name] = data[field.name]

                        if data.component:IsEnabled() then
                            data.component:Toggle(false)
                            data.component:Toggle(true)
                        end
                    end
                end

                ImGui.PopStyleColor(4)

                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip(('Chunk %d: %s'):format(index + 1, isSet and 'visible' or 'hidden'))
                end

                ImGui.PopID()
            end
        end
    end

    ImGui.PopStyleVar(4)
end

function view.isValidAppearanceSource(data)
    return isNotEmpty(data.appearancePath) and isNotEmpty(data.appearanceDef)
end

function view.formatAppearanceSource(data)
    return data.appearanceDef .. ' @ ' .. data.appearancePath
end

function view.isValidNodeIndex(data)
    return type(data.instanceIndex) == 'number' and data.instanceIndex >= 0
        and type(data.instanceCount) == 'number' and data.instanceCount > 0
end

function view.isValidInnerIndex(data)
    return type(data.innerIndex) == 'number' and data.innerIndex >= 0
        and type(data.innerCount) == 'number' and data.innerCount > 0
end

function view.hasValidCommunityIndex(data)
    return type(data.communityIndex) == 'number' and data.communityIndex >= 0
        and type(data.communityCount) == 'number' and data.communityCount > 0
end

function view.hasValidActorIndex(data)
    return type(data.actorIndex) == 'number' and data.actorIndex >= 0
        and type(data.actorCount) == 'number' and data.actorCount > 0
end

function view.formatActorLabel(data)
    if IsDefined(data.nodeDefinition) then
        if data.isCollisionNode then
            return 'Collision Actor:'
        end

        if data.isMeshNode then
            return 'Mesh Instance:'
        end

        if data.isFoliageNode then
            return 'Foliage Instance:'
        end

        if data.isOccluderNode then
            return 'Occluder Instance:'
        end
    end

    return 'Node Actor:'
end

function view.hasValidShapeIndex(data)
    return type(data.shapeIndex) == 'number' and data.shapeIndex >= 0
        and type(data.shapeCount) == 'number' and data.shapeCount > 0
end

function view.formatShapeLabel(data)
    if IsDefined(data.nodeDefinition) then
        if data.isCollisionNode then
            return 'Collision Shape:'
        end
    end

    return 'Node Shape:'
end

function view.hasValidCommunityEntryIndex(data)
    return type(data.communityEntryIndex) == 'number' and data.communityEntryIndex >= 0
        and type(data.communityEntryCount) == 'number' and data.communityEntryCount > 0
end

function view.isValidCommunityRegistry(data)
    return type(data.communityRegistryPath) == 'string'
        and type(data.communityRegistryIndex) == 'number' and data.communityRegistryIndex > 0
end

function view.formatCommunityRegistry(data)
    return ('%s (%d)'):format(data.communityRegistryPath, data.communityRegistryIndex)
end

function view.hasValidComponentInfo(data)
    return type(data.componentName) == 'string' and type(data.componentType) == 'string'
end

view.resultSchema = {
    {
        { name = 'nodeType', label = 'Node Type:' },
        { name = 'nodeID', label = 'Node ID:', format = '%u' },
        { name = 'nodeRef', label = 'Node Ref:', wrap = true },
        { name = 'nodeProxyRef', label = 'Node Proxy:', wrap = true },
        { name = 'nodeParentRef', label = 'Node Parent:', wrap = true },
        { name = 'nodePosition', label = 'Node Position:', format = view.formatPosition, validate = view.isValidPosition },
        { name = 'nodeOrientation', label = 'Node Orientation:', format = view.formatOrientation, validate = view.isValidOrientation },
        { name = 'nodeScale', label = 'Node Scale:', format = view.formatScale, validate = view.isValidScale },
        { name = 'sectorPath', label = 'Node Sector:', wrap = true },
        { name = 'nodeIndex', label = 'Node Definition:', format = '%d', validate = view.isValidNodeIndex },
        { name = 'nodeCount', label = '/', format = '%d', inline = true, validate = view.isValidNodeIndex },
        { name = 'instanceIndex', label = 'Node Instance:', format = '%d', validate = view.isValidNodeIndex },
        { name = 'instanceCount', label = '/', format = '%d', inline = true, validate = view.isValidNodeIndex },
        { name = 'innerIndex', label = 'Cooked Instance:', format = '%d', validate = view.isValidInnerIndex },
        { name = 'innerCount', label = '/', format = '%d', inline = true, validate = view.isValidInnerIndex },
        { name = 'debugName', label = 'Debug Name:' },
        { name = 'sourcePrefabHash', label = 'Source Prefab Hash:', format = '%u' },
    },
    {
        { name = 'communityID', label = 'Community ID:', format = '%u' },
        { name = 'communityEntryName', label = 'Community Entry Name:' },
        { name = 'communityEntryPhase', label = 'Community Entry Phase:' },
        { name = 'communityRegistry', label = 'Community Registry:', format = view.formatCommunityRegistry, wrap = true, validate = view.isValidCommunityRegistry },
        { name = 'communityIndex', label = 'Community Index:', format = '%d', validate = view.hasValidCommunityIndex },
        { name = 'communityCount', label = '/', format = '%d', inline = true, validate = view.hasValidCommunityIndex },
        { name = 'communityEntryIndex', label = 'Community Entry Index:', format = '%d', validate = view.hasValidCommunityEntryIndex },
        { name = 'communityEntryCount', label = '/', format = '%d', inline = true, validate = view.hasValidCommunityEntryIndex },
    },
    {
        { name = 'entityType', label = 'Entity Type:' },
        { name = 'entityID', label = 'Entity ID:', format = '%u' },
        { name = 'recordID', label = 'Record ID:' },
        { name = 'vendorID', label = 'Vendor ID:' },
        { name = 'templatePath', label = 'Entity Template:', wrap = true },
        { name = 'appearanceName', label = 'Entity Appearance:', wrap = true },
        { name = 'deviceClass', label = 'Device Class:' },
        { name = 'entityPosition', label = 'Entity Position:', format = view.formatPosition },
        { name = 'entityOrientation', label = 'Entity Orientation:', format = view.formatOrientation },
        { name = 'componentType', label = 'Hit Component:', wrap = true, validate = view.hasValidComponentInfo },
        { name = 'componentName', label = '·', inline = true, validate = view.hasValidComponentInfo },
        { name = 'meshPath', label = 'Mesh Resource:', wrap = true },
        { name = 'meshAppearance', label = 'Mesh Appearance:', wrap = true },
        { name = 'materialPath', label = 'Material Resource:', wrap = true },
        { name = 'particlePath', label = 'Particle Resource:', wrap = true },
        { name = 'effectPath', label = 'Effect Resource:', wrap = true },
        { name = 'workspotPath', label = 'Workspot Resource:', wrap = true },
        { name = 'foliagePath', label = 'Foliage Resource:', wrap = true },
        { name = 'occluderType', label = 'Occluder Type:' },
        { name = 'actorIndex', label = view.formatActorLabel, format = '%d', validate = view.hasValidActorIndex },
        { name = 'actorCount', label = '/', format = '%d', inline = true, validate = view.hasValidActorIndex },
        { name = 'shapeIndex', label = view.formatShapeLabel, format = '%d', validate = view.hasValidShapeIndex },
        { name = 'shapeCount', label = '/', format = '%d', inline = true, validate = view.hasValidShapeIndex },
        { name = 'triggerNotifiers', label = 'Trigger Notifiers:', format = view.formatArrayField, validate = view.isValidArrayField },
        { name = 'lootTables', label = 'Loot Tables:', format = view.formatArrayField, validate = view.isValidArrayField },
    },
    {
        { name = 'resolvedPath', label = 'Resource:', wrap = true },
        { name = 'resolvedName', label = 'CName:', wrap = true },
        { name = 'resolvedTDBID', label = 'TweakDBID:', wrap = true },
    }
}

view.componentSchema = {
    { name = 'componentType', label = 'Type:' },
    { name = 'componentName', label = 'Name:', wrap = true },
    { name = 'componentID', label = 'ID:', format = '%u' },
    { name = 'rigPath', label = 'Rig:', wrap = true },
    { name = 'animGraphPath', label = 'Graph:', wrap = true },
    { name = 'morphPath', label = 'Morph Target:', wrap = true },
    { name = 'meshPath', label = 'Mesh:', wrap = true },
    { name = 'meshAppearance', label = 'Appearance:', wrap = true },
    { name = 'chunkMask', label = 'Chunk Mask:', render = view.drawBitEditor, validate = view.isValidChunkMask },
    { name = 'effects', label = 'Effects:', format = view.formatArrayField, validate = view.isValidArrayField, wrap = true },
    { name = 'appearancePath', label = 'Source:', format = view.formatAppearanceSource, validate = view.isValidAppearanceSource, wrap = true },
}

view.attachmentSchema = {
    { name = 'slotID', label = 'Slot ID:' },
    { name = 'itemID', label = 'Item ID:', wrap = true },
    { name = 'itemType', label = 'Item Type:' },
    { name = 'templatePath', label = 'Item Template:', wrap = true },
    { name = 'appearanceName', label = 'Item Appearance:', wrap = true },
}

function view.isVisibleField(field, data)
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

function view.drawField(field, data)
    local label = field.label
    if type(label) == 'function' then
        label = label(data, field)
    end

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

    if type(field.render) == 'function' then
        field.render(data, field)
        return
    end

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

function view.drawComponentToggle(componentData, toggleX)
    local component = componentData.component

    if not IsDefined(component) then
        return
    end

    ImGui.SameLine(toggleX)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, viewStyle.defaultFrameBg)
    local enabled, changed = ImGui.Checkbox('##RHT:WorldTools:ComponentToggle:' .. tostring(componentData.hash), component:IsEnabled())
    if changed then
        component:Toggle(enabled)
    end
    ImGui.PopStyleColor()
end

function view.drawComponents(components)
    local toggleX, labelWidth

    for _, componentData in ipairs(components) do
        if componentData.filtered ~= false then
            ImGui.BeginGroup()

            if toggleX == nil or labelWidth == nil then
                local indentX = ImGui.GetCursorPosX()
                local rowRightX = indentX + ImGuiEx.GetContentRegionAvailWidth()
                toggleX = rowRightX - viewStyle.componentToggleWidth - viewStyle.componentToggleMarginX
                labelWidth = toggleX - indentX - viewStyle.treeNodeArrowWidth - viewStyle.treeNodePaddingX
            end

            local label = ImGuiEx.TruncateText(componentData.description, labelWidth)
            local isOpen = ImGui.TreeNodeEx(label .. '###' .. tostring(componentData.hash), ImGuiTreeNodeFlags.SpanFullWidth + ImGuiTreeNodeFlags.AllowItemOverlap)

            if isOpen then
                for _, field in ipairs(view.componentSchema) do
                    if view.isVisibleField(field, componentData) then
                        view.drawField(field, componentData)
                    end
                end
                ImGui.TreePop()
            end

            ImGui.EndGroup()

            if ImGui.IsItemHovered() and componentData.component:IsA('entIVisualComponent') then
                highlighting.setTarget(componentData)
            end

            view.drawComponentToggle(componentData, toggleX)
        end
    end
end

function view.drawAttachments(attachments)
    for _, attachmentData in ipairs(attachments) do
        if attachmentData.filtered ~= false then
            local flags = ImGuiTreeNodeFlags.SpanFullWidth
            if not attachmentData.itemID then
                flags = flags + ImGuiTreeNodeFlags.Leaf
            end

            if ImGui.TreeNodeEx(attachmentData.slotID .. '##' .. tostring(attachmentData.hash), flags) then
                if attachmentData.itemID then
                    for _, field in ipairs(view.attachmentSchema) do
                        if view.isVisibleField(field, attachmentData) then
                            view.drawField(field, attachmentData)
                        end
                    end

                    view.drawExtras(attachmentData)
                end

                ImGui.TreePop()
            end
        end
    end
end

function view.drawItemList(items)
    for _, item in ipairs(items) do
        if item.filtered ~= false then
            ImGui.Selectable(item.value)
            if ImGui.IsItemClicked(ImGuiMouseButton.Middle) then
                ImGui.SetClipboardText(item.value)
            end
        end
    end
end

function view.drawExtraTreeNode(label, numFiltered, numTotal)
    if numFiltered == nil then
        numFiltered = numTotal
    end

    local isOpen = false
    local hasChildren = numFiltered > 0
    local counterLabel = numFiltered ~= numTotal and (' (%d / %d)'):format(numFiltered, numTotal) or (' (%d)'):format(numTotal)
    local fullLabel = label .. counterLabel .. '###' .. label

    if hasChildren then
        isOpen = ImGui.TreeNodeEx(fullLabel, ImGuiTreeNodeFlags.SpanFullWidth)
    else
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
        ImGui.TreeNodeEx(fullLabel, ImGuiTreeNodeFlags.SpanFullWidth + ImGuiTreeNodeFlags.NoTreePushOnOpen)
        ImGui.PopStyleColor()
    end

    return isOpen
end

function view.drawExtras(targetData)
    if targetData.hasComponents then
        if view.drawExtraTreeNode('Components', targetData.numFilteredComponents, targetData.numComponents) then
            view.drawComponents(targetData.components)
            ImGui.TreePop()
        end
    end

    if targetData.hasAttachments then
        if view.drawExtraTreeNode('Attachments', targetData.numFilteredAttachments, targetData.numAttachments) then
            view.drawAttachments(targetData.attachments)
            ImGui.TreePop()
        end
    end

    if targetData.hasInventory then
        if view.drawExtraTreeNode('Inventory', targetData.numFilteredInventory, targetData.numInventory) then
            view.drawItemList(targetData.inventory)
            ImGui.TreePop()
        end
    end

    if targetData.hasVisualTags then
        if view.drawExtraTreeNode('Visual Tags', targetData.numFilteredVisualTags, targetData.numVisualTags) then
            view.drawItemList(targetData.visualTags)
            ImGui.TreePop()
        end
    end
end

function view.drawFieldset(targetData, withSeparators, withExtras, withExtrasFrame)
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
    for _, groupSchema in ipairs(view.resultSchema) do
        local isFirstField = true
        for _, field in ipairs(groupSchema) do
            if view.isVisibleField(field, targetData) then
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
                view.drawField(field, targetData)
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

        --if hasExtras and withExtrasFrame then
        --    ImGui.BeginChildFrame(1, 0, 15 * ImGui.GetFrameHeightWithSpacing())
        --end

        view.drawExtras(targetData)

        --if hasExtras and withExtrasFrame then
        --    ImGui.EndChildFrame()
        --end
    end

    ImGui.PopStyleColor()
    ImGui.PopStyleVar(2)

    local actions = view.getTargetActions(targetData, withExtras)
    if #actions > 0 then
        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, viewStyle.defaultFramePaddingX, viewStyle.defaultFramePaddingY)

        if withSeparators then
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()
        else
            ImGui.Spacing()
        end

        local fullWidth = ImGui.GetContentRegionMax()
        local frameHeight = ImGui.GetFrameHeight()
        local itemSpacing = ImGui.GetFrameHeightWithSpacing() - frameHeight

        for index, action in ipairs(actions) do
            local inline = action.inline and index > 1

            if inline then
                local actionWidth = ImGui.CalcTextSize(action.label) + itemSpacing * 3
                if action.type == 'checkbox' then
                    actionWidth = actionWidth + frameHeight + itemSpacing
                end

                local leftWidth = fullWidth - ImGui.GetCursorPosX()
                if actionWidth > leftWidth then
                    inline = false
                end
            end

            if action.type == 'button' then
                if inline then
                    ImGui.SameLine()
                end
                if ImGui.Button(action.label) then
                    action.callback(targetData)
                end
            elseif action.type == 'checkbox' then
                if inline then
                    ImGui.SameLine()
                end
                local _, pressed = ImGui.Checkbox(action.label, action.state)
                if pressed then
                    action.callback(targetData)
                end
            end
        end

        ImGui.PopStyleVar()
    end
end

-- GUI :: Inspector --

function view.drawInspectorContent(isModal)
    ImGui.Text(view.targetingModeOptions[TargetingMode.values[userState.targetingMode]])

    if inspectionSystem:GetStreamingOverrideState() then
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
        ImGui.Text('+')
        ImGui.PopStyleColor()
        ImGui.SameLine()
        ImGui.Text('Observer Override')
    end

    if inspector.active then
        local selected = inspector.results[inspector.active]
        if selected.distance then
            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
            ImGui.Text('@')
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.Text(view.formatDistance(selected.distance))
        end
        local extra = {}
        if selected.collision then
            table.insert(extra, selected.collision.name.value)
        end
        if selected.interior then
           table.insert(extra, 'Interior')
        end
        if selected.isCollisionNode then
            table.insert(extra, view.collisionGranularityOptions[CollisionGranularity.values[userState.collisionGranularity]])
        end
        if #extra > 0 then
            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
            ImGui.Text('(' .. table.concat(extra, ', ') .. ')')
            ImGui.PopStyleColor()
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
                if ImGui.Button(tostring(index), viewStyle.inspectorTargetWidth, 0) then
                    inspector.selectResult(index)
                end
                if not isActive then
                    ImGui.PopStyleColor()
                    ImGui.PopStyleVar()
                end
                ImGui.PopStyleVar()
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip(inspector.results[index].nodeType)
                end
                if index % 16 ~= 0 then
                    ImGui.SameLine()
                end
            end
            ImGui.EndGroup()
        end
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        if not isModal then
            local resultTopY = ImGui.GetCursorPosY()
            local resultBottomY
            local contentRightX

            ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 0)
            ImGui.BeginChild('##RHT:WorldTools:Inspect:Result', 0, ImGuiEx.GetContentRegionAvailHeight())
            view.drawFieldset(selected, true, true, false)
            contentRightX = ImGui.GetCursorPosX() + ImGuiEx.GetContentRegionAvailWidth()
            ImGui.EndChild()
            ImGui.PopStyleVar()
            resultBottomY = ImGui.GetCursorPosY()

            if selected.hasComponents or selected.hasAttachments or selected.hasInventory or selected.hasVisualTags then
                local filterFrameBg = viewState.inspectorFilterActive and viewStyle.inspectorFilterBg or 0
                local filterWidth = viewState.inspectorFilterActive and viewStyle.inspectorFilterWidth or (viewStyle.fontSize + viewStyle.windowPaddingX)
                local filterHint = viewState.inspectorFilterActive and '' or '󰺮'

                ImGui.SetCursorPosX(contentRightX - filterWidth + viewStyle.windowPaddingX)
                ImGui.SetCursorPosY(resultTopY)

                ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 0)
                ImGui.PushStyleColor(ImGuiCol.ChildBg, 0)
                ImGui.BeginChild('##RHT:WorldTools:Inspect:FilterWrapper', filterWidth, viewStyle.inspectorFilterHeight, 0, ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse)
                ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 1.0)
                ImGui.PushStyleColor(ImGuiCol.FrameBg, filterFrameBg)
                ImGui.PushStyleColor(ImGuiCol.TextDisabled, viewStyle.hintTextColor)
                ImGui.SetNextItemWidth(filterWidth)
                local filtetText, filterChanged = ImGui.InputTextWithHint('##InspectorFilter', filterHint, viewState.inspectorFilter, view.maxInputLen)
                if filterChanged then
                    viewState.inspectorFilter = ImGuiEx.SanitizeInputText(filtetText)
                end
                viewState.inspectorFilterActive = isNotEmpty(viewState.inspectorFilter) or ImGui.IsItemActive()
                ImGui.PopStyleColor(2)
                ImGui.PopStyleVar()
                ImGui.EndChild()
                ImGui.PopStyleColor()
                ImGui.PopStyleVar()

                ImGui.SetCursorPosY(resultBottomY)
            end
        else
            view.drawFieldset(selected, true, false, false)
        end
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

function view.drawScannerContent(isModal)
    if isModal then
        if scanner.hovered and scanner.results[scanner.hovered] then
            ImGui.Text(('Scan Result #%d'):format(scanner.hovered))
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()
            view.drawFieldset(scanner.results[scanner.hovered], true, true, false)
        else
            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.labelTextColor)
            ImGui.Text('No scan results')
            ImGui.PopStyleColor()
        end
        return
    end

    ImGui.TextWrapped('Search for non-collision, hidden and unreachable world nodes.')
    ImGui.Spacing()

    if ImGui.Button('Scan world nodes', ImGuiEx.GetContentRegionAvailWidth(), viewStyle.buttonHeight) then
        scanner.requestScan()
    end

    if scanner.finished then
        if not userState.keepLastHoveredResultHighlighted then
            scanner.unselectResult()
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
            local groupIndex, groupChanged = ImGui.Combo('##ScannerGroup', view.nodeGroupOptions[userState.scannerGroup] - 1, view.nodeGroupOptions, #view.nodeGroupOptions)
            if groupChanged then
                userState.scannerGroup = groupIndex ~= 0 and view.nodeGroupOptions[groupIndex + 1] or ''
            end

            ImGui.SameLine()
            ImGui.AlignTextToFramePadding()
            ImGui.Text('Filter:')
            ImGui.SameLine()
            ImGui.SetNextItemWidth(viewStyle.scannerFilterWidth)
            ImGui.PushStyleColor(ImGuiCol.TextDisabled, viewStyle.hintTextColor)
            local filter, filterChanged = ImGui.InputTextWithHint('##ScannerFilter', '', userState.scannerFilter, view.maxInputLen)
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
            ImGui.SetNextItemWidth(-1)
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

                ImGui.BeginChildFrame(1, 0, ImGuiEx.GetContentRegionAvailHeight())

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
                        view.drawFieldset(result, false, true, false)
                        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
                        ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)
                        ImGui.TreePop()
                    end
                    ImGui.EndGroup()
                    if ImGui.IsItemHovered() then
                        scanner.selectResult(result.index)
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

function view.drawLookupContent()
    ImGui.TextWrapped('Search world nodes and spawned entities by their identities.')
    ImGui.Spacing()
    ImGui.SetNextItemWidth(ImGuiEx.GetContentRegionAvailWidth())
    ImGui.PushStyleColor(ImGuiCol.TextDisabled, viewStyle.hintTextColor)
    local query, queryChanged = ImGui.InputTextWithHint('##LookupQuery', 'Enter node reference or entity id or hash', viewState.lookupQuery, view.maxInputLen)
    if queryChanged then
        viewState.lookupQuery = ImGuiEx.SanitizeInputText(query)
    end
    ImGui.PopStyleColor()

    if lookup.result then
        if not lookup.empty then
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()
            ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 0)
            ImGui.BeginChild('##RHT:WorldTools:Lookup:Result', 0, ImGuiEx.GetContentRegionAvailHeight())
            view.drawFieldset(lookup.result, true, true, false)
            ImGui.EndChild()
            ImGui.PopStyleVar()
        else
            ImGui.Spacing()
            ImGui.PushStyleColor(ImGuiCol.Text, viewStyle.mutedTextColor)
            ImGui.TextWrapped('Nothing found')
            ImGui.PopStyleColor()
        end
    end
end

-- GUI :: Watcher --

function view.drawWatcherContent()
    ImGui.Text('Watch tracked entities. Player related entities are auto-tracked.')

    ImGui.Spacing()
    ImGui.PushStyleColor(ImGuiCol.TextDisabled, viewStyle.hintTextColor)
    ImGui.SetNextItemWidth(ImGuiEx.GetContentRegionAvailWidth())
    local filterText, filterChanged = ImGui.InputTextWithHint('##WatcherFilter', 'Filter components, inventory, attachments, tags, etc.', viewState.watcherFilter, view.maxInputLen)
    if filterChanged then
        viewState.watcherFilter = ImGuiEx.SanitizeInputText(filterText)
    end
    ImGui.PopStyleColor()

    if watcher.numTargets > 0 then
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 0)
        ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)

        ImGui.BeginChildFrame(1, 0, ImGuiEx.GetContentRegionAvailHeight())

        for _, result in pairs(watcher.results) do
            if ImGui.TreeNodeEx(result.description, ImGuiTreeNodeFlags.SpanFullWidth) then
                view.drawFieldset(result, false, true, false)
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

-- GUI :: Streaming --

function view.drawStreamingContent()
    ImGui.BeginChild('##RHT:WorldTools:Streaming', 0, ImGuiEx.GetContentRegionAvailHeight())

    local state, changed

    state = inspectionSystem:GetStreamingOverrideState()

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Observer override:')
    ImGui.SameLine()
    ImGui.BeginGroup()
    if state then
        ImGui.PushStyleColor(ImGuiCol.Button, 0xFF00AA00)
    end
    if ImGui.Button(' ON ', 50, 0) then
        inspectionSystem:SetStreamingOverrideState(true)
    end
    if state then
        ImGui.PopStyleColor()
    end
    ImGui.SameLine()
    ImGui.Text('/')
    ImGui.SameLine()
    if not state then
        ImGui.PushStyleColor(ImGuiCol.Button, 0xFF000088)
    end
    if ImGui.Button(' OFF ', 50, 0) then
        inspectionSystem:SetStreamingOverrideState(false)
    end
    if not state then
        ImGui.PopStyleColor()
    end
    ImGui.EndGroup()
    ImGui.EndGroup()

    ImGui.Spacing()

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Observer position:')
    ImGui.SameLine()
    ImGui.BeginGroup()
    ImGui.SetNextItemWidth(viewStyle.settingsShortInputWidth)
    local position = inspectionSystem:GetStreamingOverridePosition()
    position.x, changed = ImGui.DragFloat('##ObserverPositionX', position.x, 0.01, -9999, 9999, 'X: %.3f', ImGuiSliderFlags.AlwaysClamp)
    if changed then
        inspectionSystem:SetStreamingOverridePosition(position)
    end
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsShortInputWidth)
    position.y, changed = ImGui.DragFloat('##ObserverPositionY', position.y, 0.01, -9999, 9999, 'Y: %.3f', ImGuiSliderFlags.AlwaysClamp)
    if changed then
        inspectionSystem:SetStreamingOverridePosition(position)
    end
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsShortInputWidth)
    position.z, changed = ImGui.DragFloat('##ObserverPositionZ', position.z, 0.01, -9999, 9999, 'Z: %.3f', ImGuiSliderFlags.AlwaysClamp)
    if changed then
        inspectionSystem:SetStreamingOverridePosition(position)
    end
    ImGui.Spacing()
    if ImGui.Button('Set to player', viewStyle.settingsShortInputWidth, 0) then
        inspectionSystem:SetStreamingOverridePosition(GetPlayer():GetWorldPosition())
    end
    ImGui.SameLine()
    if ImGui.Button('Reset to zero', viewStyle.settingsShortInputWidth, 0) then
        inspectionSystem:SetStreamingOverridePosition(Vector4.new())
    end
    ImGui.Spacing()
    state, changed = ImGui.Checkbox('Sync with player on hotkey activation', userState.syncObserverPositionWithPlayer)
    if changed then
        userState.syncObserverPositionWithPlayer = state
    end
    ImGui.EndGroup()
    ImGui.EndGroup()

    ImGui.EndChild()
end

-- GUI :: Settings --

function view.drawSettingsContent()
    ImGui.BeginChild('##RHT:WorldTools:Settings', 0, ImGuiEx.GetContentRegionAvailHeight())

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
    state, changed = ImGui.Combo('##WindowSnapping', WindowSnapping.values[userState.windowSnapping] - 1, view.windowSnappingOptions, #view.windowSnappingOptions)
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
    ImGui.Text('Show outline:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsLongComboRowWidth - ImGui.GetCursorPosX())
    state, changed = ImGui.Combo('##OutlineMode', OutlineMode.values[userState.outlineMode] - 1, view.outlineModeOptions, #view.outlineModeOptions)
    if changed then
       userState.outlineMode = OutlineMode.values[state + 1]
    end
    ImGui.EndGroup()

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Show origin point:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsLongComboRowWidth - ImGui.GetCursorPosX())
    state, changed = ImGui.Combo('##MarkerMode', MarkerMode.values[userState.markerMode] - 1, view.markerModeOptions, #view.markerModeOptions)
    if changed then
       userState.markerMode = MarkerMode.values[state + 1]
    end
    ImGui.EndGroup()

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Show bounding box:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsLongComboRowWidth - ImGui.GetCursorPosX())
    state, changed = ImGui.Combo('##BoundingBoxMode', BoundingBoxMode.values[userState.boundingBoxMode] - 1, view.boundingBoxModeOptions, #view.boundingBoxModeOptions)
    if changed then
        userState.boundingBoxMode = BoundingBoxMode.values[state + 1]
    end
    ImGui.EndGroup()

    ImGui.Spacing()

    state, changed = ImGui.Checkbox('Show distance to the origin point', userState.showMarkerDistance)
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
    state, changed = ImGui.Combo('##TargetingMode', TargetingMode.values[userState.targetingMode] - 1, view.targetingModeOptions, #view.targetingModeOptions)
    if changed then
        userState.targetingMode = TargetingMode.values[state + 1]
    end
    ImGui.EndGroup()
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        local cursorY = ImGui.GetCursorPosY()
        ImGui.Dummy(220 * viewStyle.viewScale, 0)
        ImGui.SetCursorPosY(cursorY)
        ImGui.Text(view.targetingModeOptions[1])
        ImGui.TextWrapped(
            'Uses the same ray casting method and physical data as during normal gameplay, ' ..
            'pixel accurate but cannot target non-collision meshes and decals.')
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Text(view.targetingModeOptions[2])
        ImGui.TextWrapped(
            'Uses alternative ray casting method based on static bounding boxes of world nodes, ' ..
            'ignores transparency and generally less accurate but can target non-collision meshes and decals.')
        ImGui.EndTooltip()
    end

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Collision granularity:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsMiddleComboRowWidth - ImGui.GetCursorPosX())
    state, changed = ImGui.Combo('##CollisionGranularity', CollisionGranularity.values[userState.collisionGranularity] - 1, view.collisionGranularityOptions, #view.collisionGranularityOptions)
    if changed then
        userState.collisionGranularity = CollisionGranularity.values[state + 1]
    end
    ImGui.EndGroup()

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Max targeting distance:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsMiddleInputWidth)
    state, changed = ImGui.InputFloat('##TargetingDistance', userState.targetingDistance, 1.0, 10.0, '%.1fm', ImGuiInputTextFlags.None)
    if changed then
        userState.targetingDistance = state
        userState.syncInspectionSystem()
    end
    ImGui.EndGroup()

    ImGui.BeginGroup()
    ImGui.AlignTextToFramePadding()
    ImGui.Text('Max static targets:')
    ImGui.SameLine()
    ImGui.SetNextItemWidth(viewStyle.settingsShortInputWidth)
    state, changed = ImGui.InputInt('##StaticMeshTargets', userState.maxTargets, 1, 10, ImGuiInputTextFlags.None)
    if changed then
        userState.maxTargets = MathEx.Clamp(state, 1, 32)
    end
    ImGui.EndGroup()
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip('The number of targets closest to the crosshair in Static Bounds mode.')
    end

    ImGui.Spacing()

    state, changed = ImGui.Checkbox('Cycle inspector targets', userState.cycleInspectorResults)
    if changed then
        userState.cycleInspectorResults = state
    end

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
        userState.syncInspectionSystem()
    end
    ImGui.EndGroup()

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

    ImGui.EndChild()
end

-- GUI :: Hotkeys --

function view.drawHotkeysContent()
    ImGui.BeginChild('##RHT:WorldTools:Hotkeys', 0, ImGuiEx.GetContentRegionAvailHeight())

    app.drawHotkeys(moduleID)

    ImGui.EndChild()
end

-- GUI :: Drawing --

function view.getScreenDescriptor(camera)
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

function view.getProjectedPoint(screen, point, clamp)
    local projected = inspectionSystem:ProjectWorldPoint(point)

    local result = {
        x = projected.x,
        y = projected.y,
        behind = projected.w <= 0.0,
    }

    if projected.w > 0.0 then
        result.x = result.x / projected.w
        result.y = result.y / projected.w
    end

    if clamp then
        result.x = MathEx.Clamp(result.x, -0.99, 0.99)
        result.y = MathEx.Clamp(result.y, -0.99, 0.99)
    end

    result.x = screen.centerX + (result.x * screen.centerX)
    result.y = screen.centerY - (result.y * screen.centerY)

    result.visibleX = not result.behind and result.x >= screen[1].x and result.x <= screen[3].x
    result.visibleY = not result.behind and result.y >= screen[1].y and result.y <= screen[3].y
    result.visible = result.visibleX and result.visibleY

    return result
end

function view.drawCircle(point, color, radius, thickness)
    if thickness == nil then
        ImGui.ImDrawListAddCircleFilled(ImGui.GetWindowDrawList(), point.x, point.y, radius, color, -1)
    else
        ImGui.ImDrawListAddCircle(ImGui.GetWindowDrawList(), point.x, point.y, radius, color, -1, thickness)
    end
end

function view.drawLine(line, color, thickness)
    ImGui.ImDrawListAddLine(ImGui.GetWindowDrawList(),
        line[1].x, line[1].y,
        line[2].x, line[2].y,
        color, thickness or 1)
end

function view.drawTriangle(triangle, color, thickness)
    if thickness == nil then
        ImGui.ImDrawListAddTriangleFilled(ImGui.GetWindowDrawList(),
            triangle[1].x, triangle[1].y,
            triangle[2].x, triangle[2].y,
            triangle[3].x, triangle[3].y,
            color)
    else
        ImGui.ImDrawListAddTriangle(ImGui.GetWindowDrawList(),
            triangle[1].x, triangle[1].y,
            triangle[2].x, triangle[2].y,
            triangle[3].x, triangle[3].y,
            color, thickness)
    end
end

function view.drawRoundRect(rect, color, radius, thickness)
    if thickness == nil then
        ImGui.ImDrawListAddRectFilled(ImGui.GetWindowDrawList(),
            rect[1].x, rect[1].y,
            rect[2].x, rect[2].y,
            color, radius)
    else
        ImGui.ImDrawListAddRect(ImGui.GetWindowDrawList(),
            rect[1].x, rect[1].y,
            rect[2].x, rect[2].y,
            color, thickness, radius)
    end
end

function view.drawQuad(quad, color, thickness)
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

function view.drawText(position, color, size, text)
    ImGui.ImDrawListAddText(ImGui.GetWindowDrawList(), size, position.x, position.y, color, tostring(text))
end

function view.drawBadge(origin, text, offsetX, offsetY, badgeColor, textColor, fontRatio)
    if not fontRatio then
        fontRatio = 0.8
    end

    local fontSize = viewStyle.fontSize * fontRatio
    local textWidth, textHeight = ImGui.CalcTextSize(text)

    textWidth = textWidth * fontRatio
    textHeight = textHeight * fontRatio

    local position = { x = origin.x, y = origin.y }
    local paddingX = 5
    local paddingY = 2

    if type(offsetX) == 'number' then
        position.x = position.x + (offsetX > 0 and offsetX or (offsetX - textWidth))
    else
        position.x = position.x - (textWidth / 2.0)
    end

    if type(offsetY) == 'number' then
        position.y = position.y + (offsetY > 0 and offsetY or (offsetY - textHeight))
    else
        position.y = position.y - (textHeight / 2.0)
    end

    local label = { x = position.x, y = position.y - 1 }
    local badge = {
        { x = position.x - paddingX, y = position.y - paddingX },
        { x = position.x + paddingX + textWidth, y = position.y + paddingY + textHeight },
    }

    view.drawRoundRect(badge, badgeColor, 4)

    view.drawText(label, textColor, fontSize, text)
    view.drawText(label, textColor, fontSize, text)
end

view.cubeEdgeVertices = {
    { 1, 2 },
    { 2, 4 },
    { 3, 4 },
    { 1, 3 },
    { 5, 6 },
    { 6, 8 },
    { 7, 8 },
    { 5, 7 },
    { 1, 5 },
    { 2, 6 },
    { 3, 7 },
    { 4, 8 },
}

view.cubeFaceVertices = {
    { 1, 2, 4, 3 },
    { 1, 5, 6, 2 },
    { 7, 8, 6, 5 },
    { 3, 4, 8, 7 },
    { 2, 6, 8, 4 },
    { 1, 3, 7, 5 },
}

view.cubeFaceEdges = {
    { 1, 2, 3, 4 },
    { 9, 5, 10, 1 },
    { 7, 6, 5, 8 },
    { 3, 12, 7, 11 },
    { 10, 6, 12, 2 },
    { 4, 11, 8, 9 },
}

view.cubeFadeLimit = 0.8
view.cubeFadeRangeMin = 50
view.cubeFadeRangeMax = 200

function view.makeCubeFromBox(box, position, orientation)
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

function view.drawProjectedBox(screen, projection)
    if not projection.showBoundingBox then
        return
    end

    local position = projection.target.position
    local orientation = projection.target.orientation
    local box = projection.target.boundingBox

    local vertices = view.makeCubeFromBox(box, position, orientation)
    local points = {}
    local outline = {
        { x = screen[3].x, y = screen[3].y },
        { x = screen[1].x, y = screen[1].y },
    }

    for id, vertice in ipairs(vertices) do
        local point = view.getProjectedPoint(screen, vertice)
        point.id = id
        point.distance = Vector4.Distance(screen.camera.world, vertice)

        table.insert(points, point)

        outline[1].x = math.min(outline[1].x, point.x)
        outline[2].x = math.max(outline[2].x, point.x)
        outline[1].y = math.min(outline[1].y, point.y)
        outline[2].y = math.max(outline[2].y, point.y)
    end

    if outline[1].x >= screen[3].x or outline[2].x <= screen[1].x
    or outline[1].y >= screen[3].y or outline[2].y <= screen[1].y then
        return
    end

    local edges = {}
    local faces = {}
    local clippings = {}
    local inside = true

    for id, indexes in ipairs(view.cubeEdgeVertices) do
        local edge = {}
        edge.id = id
        edge.indexes = indexes
        edge.vertices = {
            vertices[indexes[1]],
            vertices[indexes[2]],
        }
        edge.points = {
            points[indexes[1]],
            points[indexes[2]],
        }

        edge.behind = edge.points[1].behind and edge.points[2].behind

        if edge.points[1].behind ~= edge.points[2].behind then
            local b = edge.points[1].behind and 1 or 2
            local a = 3 - b

            local clipIndex = indexes[b]
            local linkIndex = indexes[a]

            local clipLine = { vertices[linkIndex], vertices[clipIndex] }
            local clipVertice, clipDistance = MathEx.IntersectPlane(screen.camera.nearPlane, clipLine)

            if clipVertice and clipDistance >= 0 then
                local clipPoint = view.getProjectedPoint(screen, clipVertice)

                edge.points[b] = clipPoint

                if not clippings[clipIndex] then
                    clippings[clipIndex] = {}
                end

                clippings[clipIndex][linkIndex] = clipPoint
            else
                edge.behind = true
            end
        end

        edge.distance = Vector4.DistanceToEdge(screen.camera.world, edge.vertices[1], edge.vertices[2])
        edge.fading = MathEx.Clamp((edge.distance - view.cubeFadeRangeMin) / (view.cubeFadeRangeMax - view.cubeFadeRangeMin), 0, 1)

        table.insert(edges, edge)
    end

    for id, indexes in ipairs(view.cubeFaceVertices) do
        local face = {}
        face.id = id
        face.indexes = indexes
        face.vertices = {
            vertices[indexes[1]],
            vertices[indexes[2]],
            vertices[indexes[3]],
            vertices[indexes[4]],
        }
        face.points = {}

        for b = 1, #indexes do
            local a = b > 1 and b - 1 or #indexes
            local c = b < #indexes and b + 1 or 1

            local aIndex = indexes[a]
            local bIndex = indexes[b]
            local cIndex = indexes[c]

            local abClip = clippings[bIndex] and clippings[bIndex][aIndex]
            local bcClip = clippings[bIndex] and clippings[bIndex][cIndex]

            if abClip then
                table.insert(face.points, clippings[bIndex][aIndex])
            end

            if not points[bIndex].behind and (abClip ~= bcClip or not abClip) then
                table.insert(face.points, points[bIndex])
            end

            if bcClip then
                table.insert(face.points, clippings[bIndex][cIndex])
            end
        end

        if #face.points >= 3 then
            local a = Vector4.new(face.points[1].x, face.points[1].y)
            local b = Vector4.new(face.points[2].x, face.points[2].y)
            local c = Vector4.new(face.points[3].x, face.points[3].y)

            local ab = Game['OperatorSubtract;Vector4Vector4;Vector4'](b, a)
            local ac = Game['OperatorSubtract;Vector4Vector4;Vector4'](c, a)
            local normal = Vector4.Cross(ab, ac)

            face.front = normal.z <= 0

            if face.front then
                inside = false

                for _, edgeId in ipairs(view.cubeFaceEdges[face.id]) do
                    edges[edgeId].front = true

                    for _, index in ipairs(edges[edgeId].indexes) do
                        points[index].front = true
                    end
                end
            end
        end

        for _, edgeId in ipairs(view.cubeFaceEdges[face.id]) do
            face.distance = math.min(face.distance or 999, edges[edgeId].distance)
            face.fading = MathEx.Clamp((face.distance - view.cubeFadeRangeMin) / (view.cubeFadeRangeMax - view.cubeFadeRangeMin), 0, 1)
        end

        table.insert(faces, face)
    end

    local frontFaceColor = projection.profile.fillingColor
    local frontEdgeShadow = projection.profile.shadingColor
    local frontEdgeColor = projection.profile.primaryColor
    local backEdgeColor = ImGuiEx.Fade(frontEdgeColor, 0x44)
    local edgeWidth = 2
    local labelColor = projection.profile.labelColor

    for _, face in ipairs(faces) do
        if face.front then
            local faceColor = frontFaceColor

            --if not inside and face.fading > 0 then
            --    local faceOpacity = MathEx.Clamp(ImGuiEx.Opacity(faceColor) + 0x44 * face.fading, 0x11, 0x55)
            --    faceColor = ImGuiEx.Fade(faceColor, faceOpacity)
            --end

            if #face.points > 4 then
                local start = 0
                local visible = false
                for i = 1, #face.points do
                    local j = i < #face.points and i + 1 or 1
                    if face.points[i].visible then
                        if face.points[j].visible then
                            start = i
                            visible = true
                            break
                        elseif not visible then
                            start = i
                            visible = true
                        end
                    elseif face.points[i].visibleY and face.points[j].visibleY then
                        if not visible then
                            start = i
                        end
                    end
                end
                if start ~= 0 then
                    start = start > 1 and start - 1 or #face.points
                    while start ~= 1 do
                        table.insert(face.points, table.remove(face.points, 1))
                        start = start - 1
                    end
                end
            end

            local offset = 2
            if #face.points >= 4 then
                view.drawQuad(face.points, faceColor)
                offset = 4
            end

            for i = offset, #face.points - 1 do
                view.drawTriangle({ face.points[1], face.points[i], face.points[i + 1] }, faceColor)
            end
        end
    end

    --if inside then
    --    drawQuad(screen, frontFaceColor)
    --end

    for _, edge in ipairs(edges) do
        if edge.front then
            view.drawLine(edge.points, frontEdgeShadow, edgeWidth + 1)
        end
    end

    for _, edge in ipairs(edges) do
        if not edge.behind then
            local edgeColor = edge.front and frontEdgeColor or backEdgeColor

            if not inside and edge.fading then
                local faceOpacity = MathEx.Clamp(ImGuiEx.Opacity(edgeColor) * (1 - edge.fading * view.cubeFadeLimit), edge.front and 0x88 or 0x44, 0xFF)
                edgeColor = ImGuiEx.Fade(edgeColor, faceOpacity)
            end

            view.drawLine(edge.points, edgeColor, edgeWidth)
        end
    end

    local shown = 0
    local nearest = 0
    local farthest = 0
    local bounds = {}
    local showBounds = false

    local origin = view.getProjectedPoint(screen, position, true)
    origin.distance = Vector4.Distance(screen.camera.world, position)

    for _, point in ipairs(points) do
        if point.visible then
            if nearest == 0 or point.distance < points[nearest].distance then
                nearest = point.id
            end

            if farthest == 0 or point.distance > points[farthest].distance then
                farthest = point.id
            end

            shown = shown + 1
        end
    end

    table.insert(bounds, points[nearest])
    if nearest ~= farthest and farthest ~= 0 then
        table.insert(bounds, points[farthest])
    end

    if #bounds > 0 then
        if inside or not origin.visible then
            showBounds = true
        else
            outline[1].x = math.max(outline[1].x, screen[1].x)
            outline[2].x = math.min(outline[2].x, screen[3].x)
            outline[1].y = math.max(outline[1].y, screen[1].y)
            outline[2].y = math.min(outline[2].y, screen[3].y)

            local outlineArea = (outline[2].x - outline[1].x) * (outline[2].y - outline[1].y)
            local screenArea = (screen[3].x - screen[1].x) * (screen[3].y - screen[1].y)
            local coverage = outlineArea / screenArea

            if shown <= 4 then
                showBounds = coverage >= 0.3
            elseif shown <= 6 then
                showBounds = coverage >= 0.3 and bounds[1].distance >= 10
            else
                showBounds = (coverage >= 0.1 and bounds[1].distance >= 50)
                    or (coverage >= 0.2 and bounds[1].distance >= 20)
            end
        end

        if showBounds then
            for _, point in ipairs(bounds) do
                local pointColor = ImGuiEx.FadeFactor(point.front and frontEdgeColor or backEdgeColor, 1.1)

                view.drawCircle(point, pointColor, 4)
                view.drawCircle(point, labelColor, 2)

                if projection.showBoundingBoxDistances then
                    view.drawBadge(point, view.formatDistance(point.distance), true, point.front and -10 or 11, pointColor, labelColor)
                end

                if projection.showOrigin then
                    if math.abs(point.x - origin.x) <= 40 and math.abs(point.y - origin.y) <= 40 then
                        projection.showOrigin = false
                    end
                end
            end
        end
    end
end

function view.drawProjectedOrigin(screen, projection)
    if not projection.showOrigin then
        return
    end

    local position = projection.target.position
    local point = view.getProjectedPoint(screen, position, true)

    view.drawCircle(point, projection.profile.primaryColor, 5)
    view.drawCircle(point, projection.profile.labelColor, 3)

    if projection.showOriginDistance then
        local distance = Vector4.Distance(screen.camera.world, position)
        view.drawBadge(point, view.formatDistance(distance), true, -12, projection.profile.primaryColor, projection.profile.labelColor)
    end
end

function view.drawProjections()
    if not userState.isModuleActive then
        return
    end

    if next(highlighting.projections) == nil then
        return
    end

    local camera = targeting.getCameraData()

    if not camera then
        return
    end

    local screen = view.getScreenDescriptor(camera)

    ImGui.SetNextWindowSize(screen.width, screen.height, ImGuiCond.Always)
    ImGui.SetNextWindowPos(0, 0, ImGuiCond.Always)

    if ImGui.Begin('##RHT:WorldTools:Projections', true, viewStyle.projectionWindowFlags) then
        for _, projection in pairs(highlighting.projections) do
            resolving.updateGeometryData(highlighting.target)
            view.drawProjectedBox(screen, projection)
            view.drawProjectedOrigin(screen, projection)
        end
    end

    ImGui.End()
end

-- GUI :: Windows --

function view.pushWindowStyle()
    local autoHeightMode = not viewState.isConsoleOpen

    if autoHeightMode then
        ImGui.SetNextWindowSizeConstraints(viewStyle.windowMinWidth, 0, viewStyle.windowMaxWidth, viewStyle.windowMaxHeight)
        ImGui.SetNextWindowSize(userState.windowWidth, 0, ImGuiCond.Always)
    else
        ImGui.SetNextWindowSizeConstraints(viewStyle.windowMinWidth, viewStyle.windowMinHeight, viewStyle.windowMaxWidth, viewStyle.windowMaxHeight)
        if view.currentWindowHeightMode ~= autoHeightMode then
            ImGui.SetNextWindowSize(firstNotEmpty(userState.windowWidth, viewStyle.windowMinWidth), firstNotEmpty(userState.windowHeight, viewStyle.windowMinHeight), ImGuiCond.Always)
        end
    end

    view.currentWindowHeightMode = autoHeightMode

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, viewStyle.windowPaddingX, viewStyle.windowPaddingY)
end

function view.popWindowStyle()
    ImGui.PopStyleVar()
end

function view.snapWindow()
    if ImGui.IsAnyMouseDown() then
        return
    end

    local windowX, windowY, condition

    if userState.windowSnapping == WindowSnapping.TopLeft then
        windowX = viewStyle.windowMarginX
        windowY = viewStyle.windowMarginY
        condition = ImGuiCond.Always
    elseif userState.windowSnapping == WindowSnapping.TopRight then
        local screenWidth, _ = GetDisplayResolution()
        local windowWidth, _ = ImGui.GetWindowSize()
        windowX = screenWidth - windowWidth - viewStyle.windowMarginX
        windowY = viewStyle.windowMarginY
        condition = ImGuiCond.Always
    else
        return
    end

    ImGui.SetWindowPos(windowX, windowY, condition)
end

function view.drawOnScreenWindow()
    view.pushWindowStyle()

    ImGui.Begin('World Inspector##RHT:WorldTools', viewStyle.inspectorWindowFlags)

    view.snapWindow()

    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - 2)
    if userState.selectedTab == MainTab.Scan and userState.highlightScannerResult and scanner.hovered and scanner.results[scanner.hovered] then
        view.drawScannerContent(true)
    else
        view.drawInspectorContent(true)
    end

    ImGui.End()
    view.popWindowStyle()
end

function view.drawMainWindow()
    view.pushWindowStyle()

    viewState.isWindowOpen = ImGuiEx.Begin('World Inspector##RHT:WorldTools', app.canCloseTools(), viewStyle.mainWindowFlags)
    viewState.isWindowExpanded = not ImGui.IsWindowCollapsed()

    if viewState.isWindowOpen and viewState.isWindowExpanded then
        userState.syncWindowMetrics()
        view.snapWindow()

        app.drawSharedMenu(moduleID)

        ImGui.BeginTabBar('##RHT:WorldTools:TabBar')

        local selectedTab
        local featureTabs = {
            { id = MainTab.Inspect, draw = view.drawInspectorContent },
            { id = MainTab.Scan, draw = view.drawScannerContent },
            { id = MainTab.Watch, draw = view.drawWatcherContent },
            { id = MainTab.Lookup, draw = view.drawLookupContent },
            { id = MainTab.Streaming, draw = view.drawStreamingContent },
            { id = MainTab.Settings, draw = view.drawSettingsContent },
            { id = MainTab.Hotkeys, draw = view.drawHotkeysContent },
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
    view.popWindowStyle()

    if not viewState.isWindowOpen then
        userState.isModuleActive = false
        userState.isOnScreenDisplayActive = false
        userState.save()
    end
end

function view.onDraw()
    if not userState.isModuleActive then
        return
    end

    if not viewState.isConsoleOpen and not userState.isOnScreenDisplayActive then
        return
    end

    view.initializeStyle()

    if viewState.isConsoleOpen then
        if userState.isModuleActive and viewState.isWindowExpanded then
            view.drawProjections()
        end
        view.drawMainWindow()
    elseif userState.isOnScreenDisplayActive then
        view.drawProjections()
        view.drawOnScreenWindow()
    end
end

function view.onOverlayOpen()
    viewState.isConsoleOpen = true
end

function view.onOverlayClose()
    viewState.isConsoleOpen = false
    userState.save()
end

-- Module --

local module = {}

function module.onToggleInspectorHotkey()
    if not viewState.isConsoleOpen then
        userState.isOnScreenDisplayActive = not userState.isOnScreenDisplayActive
        if userState.isOnScreenDisplayActive then
            userState.isModuleActive = true
            viewState.isFirstOpen = true
            userState.selectedTab = MainTab.Inspect
        end
        userState.save()
    end
end

function module.onSelectNextResultHotkey()
    if not viewState.isConsoleOpen and userState.isOnScreenDisplayActive then
        inspector.cycleNext()
    end
end

function module.onSelectPrevResultHotkey()
    if not viewState.isConsoleOpen and userState.isOnScreenDisplayActive then
        inspector.cyclePrev()
    end
end

function module.onToggleTargetStateHotkey()
    if not viewState.isConsoleOpen and userState.isOnScreenDisplayActive then
        if inspector.active then
            control.toggleState(inspector.results[inspector.active])
        else
            control.toggleState()
        end
    end
end

function module.onCycleTargetingModeHotkey()
    if not viewState.isConsoleOpen and userState.isOnScreenDisplayActive then
        local nextModeIndex = TargetingMode.values[userState.targetingMode] + 1
        if nextModeIndex > #TargetingMode.values then
            nextModeIndex = 1
        end
        userState.targetingMode = TargetingMode.values[nextModeIndex]
        userState.save()
    end
end

function module.onCycleCollisionGranularityHotkey()
    if not viewState.isConsoleOpen and userState.isOnScreenDisplayActive then
        local nextModeIndex = CollisionGranularity.values[userState.collisionGranularity] + 1
        if nextModeIndex > #CollisionGranularity.values then
            nextModeIndex = 1
        end
        userState.collisionGranularity = CollisionGranularity.values[nextModeIndex]
        userState.save()
    end
end

function module.onToggleObserverOverride()
    if userState.syncObserverPositionWithPlayer then
        inspectionSystem:SetStreamingOverridePosition(GetPlayer():GetWorldPosition())
    end

    inspectionSystem:SetStreamingOverrideState(not inspectionSystem:GetStreamingOverrideState())
end

function module.onUpdateObserverPosition()
    inspectionSystem:SetStreamingOverridePosition(GetPlayer():GetWorldPosition())
end

function module.isActive()
    return userState.isModuleActive
end

function module.setActive(active)
    userState.isModuleActive = active
    if not userState.isModuleActive then
        userState.isOnScreenDisplayActive = false
    end
    userState.save()
end

function module.onInit()
    initializeSystems()
    userState.initialize()
    highlighting.initialize()
    targeting.initialize()
    watcher.initialize()
    view.initializeData()

    Cron.Every(1 / 60, function()
        if userState.isModuleActive then
            if viewState.isConsoleOpen then
                if viewState.isWindowExpanded then
                    if userState.selectedTab == MainTab.Inspect then
                        inspector.update(viewState.inspectorFilter)
                    elseif userState.selectedTab == MainTab.Scan then
                        scanner.update(userState.scannerDistance, userState.scannerGroup, userState.scannerFilter)
                    elseif userState.selectedTab == MainTab.Lookup then
                        lookup.update(viewState.lookupQuery)
                    elseif userState.selectedTab == MainTab.Watch then
                        watcher.update(viewState.watcherFilter)
                    end
                end
            elseif userState.isOnScreenDisplayActive then
                if userState.selectedTab == MainTab.Scan and userState.highlightScannerResult and scanner.hovered and scanner.results[scanner.hovered] then
                    scanner.update(userState.scannerDistance, userState.scannerGroup, userState.scannerFilter)
                else
                    inspector.update()
                end
            end
        end
        highlighting.update()
    end)
end

function module.onShutdown()
    highlighting.disable()
    userState.save()
end

return {
    events = {
        onInit = module.onInit,
        onShutdown = module.onShutdown,
        onOverlayOpen = view.onOverlayOpen,
        onOverlayClose = view.onOverlayClose,
        onDraw = view.onDraw,
    },
    tools = {
        { id = 'WorldInspector', label = 'World Inspector', isActive = module.isActive, setActive = module.setActive }
    },
    hotkeys = {
        { id = 'ToggleWorldInspector', group = 'World Inspector', label = 'Toggle overlay', callback = module.onToggleInspectorHotkey },
        { id = 'CycleTargetingMode', group = 'World Inspector', label = 'Cycle targeting modes', callback = module.onCycleTargetingModeHotkey },
        { id = 'CycleCollisionGranularity', group = 'World Inspector', label = 'Cycle collision granularities', callback = module.onCycleCollisionGranularityHotkey },
        { id = 'ToggleTargetState', group = 'World Inspector', label = 'Toggle target visibility', callback = module.onToggleTargetStateHotkey },
        { id = 'ToggleObserverOverride', group = 'World Inspector', label = 'Toggle observer override', callback = module.onToggleObserverOverride },
        { id = 'UpdateObserverPosition', group = 'World Inspector', label = 'Set observer position to player', callback = module.onUpdateObserverPosition },
        { id = 'SelectNextResult', group = 'Target Control', label = 'Select next target', callback = module.onSelectNextResultHotkey },
        { id = 'SelectPrevResult', group = 'Target Control', label = 'Select previous target', callback = module.onSelectPrevResultHotkey },
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
        GetWorldScannerFilteredResults = function()
            return scanner.filtered
        end,
        GetLookupResult = function()
            return lookup.result
        end,
        GetLookAtObjects = targeting.getLookAtTargets,
        ResolveObjectData = resolving.resolveTargetData,
    }
}
