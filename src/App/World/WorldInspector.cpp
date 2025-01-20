#include "Core/Facades/Container.hpp"
#include "Core/Facades/Log.hpp"
#include "Red/CameraSystem.hpp"
#include "Red/CommunitySystem.hpp"
#include "Red/Debug.hpp"
#include "Red/Math.hpp"
#include "Red/Physics.hpp"
#include "Red/Rendering.hpp"
#include "Red/Transform.hpp"
#include "Red/WorldNode.hpp"
#include "WorldInspector.hpp"

void App::WorldInspector::OnWorldAttached(Red::world::RuntimeScene*)
{
    m_nodeRegistry = Core::Resolve<WorldNodeRegistry>();
    m_nodeRegistry->RegisterWatcher(this);

    m_cameraSystem = Red::GetGameSystem<Red::gameICameraSystem>();

    m_nodesUpdateDelay = 0;
}

void App::WorldInspector::OnAfterWorldDetach()
{
    m_nodeRegistry->UnregisterWatcher(this);
    m_nodeRegistry->ClearRuntimeData();

    {
        std::unique_lock _(m_streamedNodesLock);
        m_streamedNodes.clear();
    }

    {
        std::unique_lock _(m_frustumNodesLock);
        m_frustumNodes.Clear();
        m_targetedNodes.Clear();
    }
}

void App::WorldInspector::OnRegisterUpdates(Red::UpdateRegistrar* aRegistrar)
{
    aRegistrar->RegisterUpdate(Red::UpdateTickGroup::FrameBegin, this, "WorldInspector/UpdateNodes",
                               [this](Red::FrameInfo& aFrame, Red::JobQueue&)
                               {
                                   if (!m_nodesUpdating)
                                   {
                                       m_nodesUpdateDelay -= aFrame.deltaTime;
                                       if (m_nodesUpdateDelay <= 0)
                                       {
                                           m_nodesUpdating = true;
                                           m_nodesUpdateDelay = FrustumUpdateFreq;

                                           Red::JobQueue().Dispatch([this] {
                                               UpdateStreamedNodes();
                                               UpdateFrustumNodes();

                                               m_nodesUpdating = false;
                                           });
                                       }
                                   }
                               });
}

void App::WorldInspector::OnNodeStreamedIn(uint64_t aNodeHash,
                                             Red::worldNode* aNodeDefinition,
                                             Red::worldINodeInstance* aNodeInstance,
                                             Red::CompiledNodeInstanceSetupInfo* aNodeSetup)
{
    std::unique_lock _(m_pendingRequestsLock);
    m_pendingRequests[aNodeHash] = {true, aNodeHash, Red::AsWeakHandle(aNodeInstance),
                                    Red::AsWeakHandle(aNodeDefinition), aNodeSetup};
}

void App::WorldInspector::OnNodeStreamedOut(uint64_t aNodeHash)
{
    std::unique_lock _(m_pendingRequestsLock);
    m_pendingRequests[aNodeHash] = {false, aNodeHash};
}

void App::WorldInspector::UpdateStreamedNodes()
{
#ifndef NDEBUG
    const auto updateStart = std::chrono::steady_clock::now();
#endif

    Core::Map<uint64_t, WorldNodeStreamingRequest> pendingRequests;
    Core::Map<uint64_t, WorldNodeStreamingRequest> postponedRequests;
    {
        std::unique_lock requestLock(m_pendingRequestsLock);
        pendingRequests = std::move(m_pendingRequests);
    }

    if (pendingRequests.empty())
        return;

    std::unique_lock updateLock(m_streamedNodesLock);
    for (const auto& [hash, request] : pendingRequests)
    {
        if (!request.streaming)
        {
            m_streamedNodes.erase(request.hash);
            continue;
        }

        auto nodeInstance = request.nodeInstance.Lock();
        auto nodeDefinition = request.nodeDefinition.Lock();

        if (!nodeInstance || !nodeDefinition)
        {
            postponedRequests[hash] = request;
            continue;
        }

        if (!Raw::WorldNodeInstance::IsAttached(nodeInstance))
        {
            postponedRequests[hash] = request;
            continue;
        }

        WorldNodeStaticSceneData streamedNode{request.nodeInstance, request.nodeDefinition, request.nodeSetup};

        auto& transform = Raw::WorldNodeInstance::Transform::Ref(nodeInstance);
        auto& scale = Raw::WorldNodeInstance::Scale::Ref(nodeInstance);

        if (Red::IsInstanceOf<Red::worldMeshNode>(nodeDefinition))
        {
            auto& meshResource = Raw::WorldMeshNodeInstance::Mesh::Ref(nodeInstance);

            if (meshResource)
            {
                Red::Box boundingBox = meshResource->boundingBox;
                Red::ScaleBox(boundingBox, scale);

                streamedNode.boundingBox = boundingBox;

                Red::TransformBox(boundingBox, transform);

                streamedNode.testBoxes.push_back(boundingBox);
                streamedNode.isStaticMesh = !Red::IsInstanceOf<Red::worldTerrainProxyMeshNode>(nodeDefinition) &&
                                            !Red::IsInstanceOf<Red::worldRoadProxyMeshNode>(nodeDefinition);
            }
            else
            {
                postponedRequests[hash] = request;
                continue;
            }
        }
        else if (Red::IsInstanceOf<Red::worldStaticDecalNode>(nodeDefinition) ||
                 Red::IsInstanceOf<Red::worldBendedMeshNode>(nodeDefinition) ||
                 Red::IsInstanceOf<Red::worldEntityNode>(nodeDefinition) ||
                 Red::IsInstanceOf<Red::worldAreaShapeNode>(nodeDefinition) ||
                 Red::IsInstanceOf<Red::worldGeometryShapeNode>(nodeDefinition) ||
                 Red::IsInstanceOf<Red::worldStaticOccluderMeshNode>(nodeDefinition))
        {
            Red::Box boundingBox{{1.0, 0.0, 0.0, 0.0}, {-1.0, 0.0, 0.0, 0.0}};
            Raw::WorldNode::GetBoundingBox(nodeDefinition, boundingBox);

            if (Red::IsValidBox(boundingBox))
            {
                Red::ScaleBox(boundingBox, scale);

                streamedNode.boundingBox = boundingBox;

                Red::TransformBox(boundingBox, transform);

                streamedNode.testBoxes.push_back(boundingBox);
                streamedNode.isStaticMesh = !Red::IsInstanceOf<Red::worldAreaShapeNode>(nodeDefinition) &&
                                            !Red::IsInstanceOf<Red::worldGeometryShapeNode>(nodeDefinition) &&
                                            !Red::IsInstanceOf<Red::worldStaticOccluderMeshNode>(nodeDefinition);
            }
            else
            {
                postponedRequests[hash] = request;
                continue;
            }
        }
        else if (Red::IsInstanceOf<Red::worldInstancedMeshNode>(nodeDefinition))
        {
            auto& instanceBoxes = Raw::WorldInstancedMeshNode::Bounds::Ref(nodeDefinition);
            if (instanceBoxes.size > 0)
            {
                for (const auto& instanceBox : instanceBoxes)
                {
                    streamedNode.testBoxes.push_back(instanceBox);
                    streamedNode.isStaticMesh = true;
                }
            }
            else
            {
                postponedRequests[hash] = request;
                continue;
            }
        }

        m_streamedNodes.emplace(request.hash, std::move(streamedNode));
    }

#ifndef NDEBUG
    const std::chrono::duration<double, std::milli> updateDuration = std::chrono::steady_clock::now() - updateStart;
    Core::Log::Debug("UpdateStreamedNodes streamed={} requests={} postponed={} time={:.3f}ms",
                     m_streamedNodes.size(), pendingRequests.size(), postponedRequests.size(), updateDuration.count());
#endif

    if (!postponedRequests.empty())
    {
        std::unique_lock requestLock(m_pendingRequestsLock);
        m_pendingRequests.reserve(postponedRequests.size());
        for (const auto& request : postponedRequests)
        {
            m_pendingRequests.insert(request);
        }
    }
}

void App::WorldInspector::UpdateFrustumNodes()
{
#ifndef NDEBUG
    std::chrono::duration<double, std::milli> initDuration{};
    std::chrono::duration<double, std::milli> resolveDuration{};
    std::chrono::duration<double, std::milli> raycastDuration{};
    std::chrono::duration<double, std::milli> commitDuration{};
    const auto updateStart = std::chrono::steady_clock::now();
#endif

    Core::Vector<WorldNodeRuntimeSceneData> frustumNodes{};
    Core::Vector<uint32_t> targetedNodeIndexes{};

    {
        std::shared_lock _(m_frustumNodesLock);
        frustumNodes.reserve(m_frustumNodes.size);
        targetedNodeIndexes.reserve(m_targetedNodes.size);
    }

    Red::Frustum cameraFrustum;
    Red::Vector4 cameraPosition{};
    Red::Vector4 cameraForward{};

    Raw::CameraSystem::GetCameraPosition(m_cameraSystem, *reinterpret_cast<Red::Vector3*>(&cameraPosition));
    Raw::CameraSystem::GetCameraForward(m_cameraSystem, cameraForward);
    Raw::CameraSystem::GetCameraFrustum(m_cameraSystem, cameraFrustum);

    const Red::Vector4 cameraInverseDirection{1.0f / cameraForward.X, 1.0f / cameraForward.Y, 1.0f / cameraForward.Z, 0.0};

#ifndef NDEBUG
    initDuration = std::chrono::steady_clock::now() - updateStart;
#endif

    {
        std::shared_lock _(m_streamedNodesLock);
        for (const auto& [hash, streamedNode] : m_streamedNodes)
        {
            if (streamedNode.nodeInstance.Expired() || streamedNode.nodeDefinition.Expired())
                continue;

            if (!Raw::WorldNodeInstance::SetupInfo::Ptr(streamedNode.nodeInstance.instance))
                continue;

            const auto& transform = streamedNode.nodeSetup->transform;
            const auto& scale = streamedNode.nodeSetup->scale;

#ifndef NDEBUG
            const auto resolveStart = std::chrono::steady_clock::now();
#endif

            Red::FrustumResult frustumResult{};
            Red::Box testBox{{1.0, 0.0, 0.0, 0.0}, {-1.0, 0.0, 0.0, 0.0}};

            if (!streamedNode.testBoxes.empty())
            {
                for (const auto& candidateBox : streamedNode.testBoxes)
                {
                    if ((frustumResult = cameraFrustum.Test(candidateBox)) != Red::FrustumResult::Outside)
                    {
                        testBox = candidateBox;
                        break;
                    }
                }
            }
            else
            {
                Red::Box dummyBox{{-0.05, -0.05, -0.05, 1.0}, {0.05, 0.05, 0.05, 1.0}};
                Red::TransformBox(dummyBox, transform);

                frustumResult = cameraFrustum.Test(dummyBox);
            }

#ifndef NDEBUG
            resolveDuration += std::chrono::steady_clock::now() - resolveStart;
            const auto raycastStart = std::chrono::steady_clock::now();
#endif

            float distance;
            if (Red::IsValidBox(testBox))
            {
                distance = Red::Distance(cameraPosition, testBox);
            }
            else
            {
                distance = Red::Distance(cameraPosition, transform.position);
            }

            auto inFrustum = (frustumResult != Red::FrustumResult::Outside && distance <= m_frustumDistance);
            if (inFrustum)
            {
                if (streamedNode.nodeDefinition.instance->isVisibleInGame &&
                    streamedNode.isStaticMesh && Red::IsValidBox(testBox) &&
                    distance >= 0.0001 && distance <= m_targetingDistance)
                {
                    if (Red::Intersect(cameraPosition, cameraInverseDirection, testBox))
                    {
                        targetedNodeIndexes.push_back(frustumNodes.size());
                    }
                }
            }
            else
            {
                continue;
            }

#ifndef NDEBUG
            raycastDuration += std::chrono::steady_clock::now() - raycastStart;
#endif

            const auto instanceHash = reinterpret_cast<uint64_t>(streamedNode.nodeInstance.instance);
            frustumNodes.push_back({streamedNode.nodeInstance, streamedNode.nodeDefinition,
                                    streamedNode.boundingBox, transform.position, transform.orientation, scale,
                                    testBox, distance, inFrustum, instanceHash, true});
        }
    }

#ifndef NDEBUG
    const auto commitStart = std::chrono::steady_clock::now();
#endif

    std::sort(targetedNodeIndexes.begin(), targetedNodeIndexes.end(),
              [&frustumNodes](uint32_t a, uint32_t b)
              {
                  return frustumNodes[a].distance < frustumNodes[b].distance;
              });

    {
        std::unique_lock _(m_frustumNodesLock);

        m_frustumNodes.Clear();
        m_frustumNodes.Reserve(frustumNodes.size());
        for (const auto& node : frustumNodes)
        {
            m_frustumNodes.PushBack(node);
        }

        m_targetedNodes.Clear();
        m_targetedNodes.Reserve(targetedNodeIndexes.size());
        for (const auto& index : targetedNodeIndexes)
        {
            m_targetedNodes.PushBack(m_frustumNodes[index]);
        }
    }

#ifndef NDEBUG
    commitDuration = std::chrono::steady_clock::now() - commitStart;

    const std::chrono::duration<double, std::milli> updateDuration = std::chrono::steady_clock::now() - updateStart;
    Core::Log::Debug("UpdateFrustumNodes streamed={} frustum={} targets={} "
                     "time={:.3f}ms init={:.3f}ms resolving={:.3f}ms raycasting={:.3f}ms commit={:.3f}ms",
                     m_streamedNodes.size(), m_frustumNodes.size, targetedNodeIndexes.size(),
                     updateDuration.count(), initDuration.count(),
                     resolveDuration.count(), raycastDuration.count(),
                     commitDuration.count());
#endif
}

App::WorldNodeInstanceStaticData App::WorldInspector::ResolveSectorDataFromNodeID(uint64_t aNodeID)
{
    {
        static const Red::GlobalNodeRef context{Red::NodeRef::GlobalRoot};

        Red::NodeRef nodeRef{aNodeID};
        Red::GlobalNodeRef resolvedRef{};
        Red::CallGlobal("ResolveNodeRef", resolvedRef, nodeRef, context);

        if (resolvedRef.hash != 0)
        {
            aNodeID = resolvedRef.hash;
        }
    }

    return m_nodeRegistry->GetNodeStaticData(aNodeID);
}

App::WorldNodeInstanceStaticData App::WorldInspector::ResolveSectorDataFromNodeInstance(
    const Red::WeakHandle<Red::worldINodeInstance>& aNodeInstance)
{
    return m_nodeRegistry->GetNodeStaticData(aNodeInstance);
}

Red::CString App::WorldInspector::ResolveNodeRefFromNodeHash(uint64_t aNodeID)
{
    if (!aNodeID)
        return {};

    {
        static const Red::GlobalNodeRef context{Red::NodeRef::GlobalRoot};

        Red::NodeRef nodeRef{aNodeID};
        Red::GlobalNodeRef resolvedRef{};
        Red::CallGlobal("ResolveNodeRef", resolvedRef, nodeRef, context);

        if (resolvedRef.hash != 0)
        {
            aNodeID = resolvedRef.hash;
        }
    }

    {
        Red::CString debugStr;
        Red::EntityID entityID{aNodeID};
        Raw::EntityID::ToStringDEBUG(entityID, debugStr);

        if (debugStr.Length() != 0)
        {
            std::string_view debugStrView(debugStr.c_str(), debugStr.Length());
            if (!debugStrView.starts_with("UNKNOWN:") && !debugStrView.starts_with("dynamic:"))
                return debugStr;
        }
    }

    return {};
}

uint64_t App::WorldInspector::ComputeNodeRefHash(const Red::CString& aNodeRef)
{
    return Red::NodeRef(aNodeRef.c_str());
}

Red::EntityID App::WorldInspector::ResolveCommunityIDFromEntityID(uint64_t aEntityID)
{
    auto entityStubSystem = Red::GetGameSystem<Red::IEntityStubSystem>();
    auto entityStub = entityStubSystem->FindStub(aEntityID);

    if (!entityStub)
        return {};

    return entityStub->stubState->spawnerId.entityId;
}

App::WorldCommunityEntryData App::WorldInspector::ResolveCommunityEntryDataFromEntityID(uint64_t aEntityID)
{
    WorldCommunityEntryData communityEntryData{};

    auto entityStubSystem = Red::GetGameSystem<Red::IEntityStubSystem>();
    auto entityStub = entityStubSystem->FindStub(aEntityID);

    if (!entityStub)
        return communityEntryData;

    auto communityID = entityStub->stubState->spawnerId.entityId;
    auto communityEntryName = entityStub->stubState->ownerCommunityEntryName;

    auto communitySystem = Red::GetGameSystem<Red::ICommunitySystem>();

    Red::WeakPtr<Red::Community> community;
    Raw::CommunitySystem::GetCommunity(communitySystem, community, communityID);

    if (!community)
    {
        return communityEntryData;
    }

    auto communitySectorData = m_nodeRegistry->GetCommunityStaticData(communityID);

    if (communitySectorData.communityID)
    {
        communityEntryData.sectorHash = communitySectorData.sectorHash;
        communityEntryData.communityIndex = communitySectorData.communityIndex;
        communityEntryData.communityCount = communitySectorData.communityCount;
        communityEntryData.communityID = communitySectorData.communityID;
    }
    else
    {
        communityEntryData.communityID = communityID;
    }

    const auto communityEntryCount = community.instance->entries.size;
    for (auto communityEntryIndex = 0; communityEntryIndex < communityEntryCount; ++communityEntryIndex)
    {
        const auto& communityEntry = community.instance->entries[communityEntryIndex];
        if (communityEntry->name == communityEntryName)
        {
            communityEntryData.entryName = communityEntryName;
            communityEntryData.entryIndex = communityEntryIndex;
            communityEntryData.entryCount = communityEntryCount;

            if (communityEntry->unk2C >= 0 && communityEntry->unk2C < communityEntry->phases.size)
            {
                communityEntryData.entryPhase = communityEntry->phases[communityEntry->unk2C];
            }

            break;
        }
    }

    return communityEntryData;
}

App::WorldNodeRuntimeSceneData App::WorldInspector::FindStreamedNode(uint64_t aNodeID)
{
    auto nodeInstance = m_nodeRegistry->FindStreamedNodeInstance(aNodeID);

    if (!nodeInstance)
        return {};

    const auto& [setup, nodeInstanceWeak, nodeDefinitionWeak] = m_nodeRegistry->GetNodeRuntimeData(nodeInstance);

    if (!nodeInstanceWeak)
        return {};

    return {nodeInstanceWeak, nodeDefinitionWeak, {}, setup->transform.position, setup->transform.orientation};
}

Red::DynArray<App::WorldNodeRuntimeSceneData> App::WorldInspector::GetStreamedNodesInFrustum()
{
    std::shared_lock _(m_frustumNodesLock);
    return m_frustumNodes;
}

Red::DynArray<App::WorldNodeRuntimeSceneData> App::WorldInspector::GetStreamedNodesInCrosshair()
{
    std::shared_lock _(m_frustumNodesLock);
    return m_targetedNodes;
}

App::WorldNodeRuntimeGeometryData App::WorldInspector::GetStreamedNodeGeometry(
    const Red::WeakHandle<Red::worldINodeInstance>& aNode)
{
    const auto& [setup, nodeInstanceWeak, nodeDefinitionWeak] = m_nodeRegistry->GetNodeRuntimeData(aNode);

    if (!setup)
        return {};

    return {setup->transform.position, setup->transform.orientation, setup->scale};
}

float App::WorldInspector::GetFrustumDistance() const
{
    return m_frustumDistance;
}

void App::WorldInspector::SetFrustumDistance(float aDistance)
{
    m_frustumDistance = std::clamp(aDistance, FrustumMinDistance, FrustumMaxDistance);
}

float App::WorldInspector::GetTargetingDistance() const
{
    return m_targetingDistance;
}

void App::WorldInspector::SetTargetingDistance(float aDistance)
{
    m_targetingDistance = std::clamp(aDistance, FrustumMinDistance, m_frustumDistance);
}

bool App::WorldInspector::SetNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance, bool aVisible)
{
    return UpdateNodeVisibility(aNodeInstance, false, true);
}

bool App::WorldInspector::ToggleNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance)
{
    return UpdateNodeVisibility(aNodeInstance, true, true);
}

bool App::WorldInspector::UpdateNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance,
                                                 bool aToggle, bool aVisible)
{
    if (Red::IsInstanceOf<Red::worldEntityNodeInstance>(aNodeInstance))
    {
        if (aToggle)
            aVisible = !Raw::WorldNodeInstance::IsVisible(aNodeInstance);

        Raw::WorldNodeInstance::SetVisibility(aNodeInstance, aVisible);
        return true;
    }

    // if (Red::IsInstanceOf<Red::worldInstancedDestructibleMeshNodeInstance>(aNodeInstance))
    // {
    //     return SetRenderProxyVisibility<Raw::WorldInstancedDestructibleMeshNodeInstance::RenderProxy>(aNodeInstance, aToggle, aVisible);
    // }

    if (Red::IsInstanceOf<Red::worldMeshNodeInstance>(aNodeInstance))
    {
        return SetRenderProxyVisibility<Raw::WorldMeshNodeInstance::RenderProxy>(aNodeInstance, aToggle, aVisible);
    }

    if (Red::IsInstanceOf<Red::worldStaticDecalNodeInstance>(aNodeInstance))
    {
        return SetRenderProxyVisibility<Raw::WorldStaticDecalNodeInstance::RenderProxy>(aNodeInstance, aToggle, aVisible);
    }

    if (Red::IsInstanceOf<Red::worldBendedMeshNodeInstance>(aNodeInstance))
    {
        return SetRenderProxyVisibility<Raw::WorldBendedMeshNodeInstance::RenderProxy>(aNodeInstance, aToggle, aVisible);
    }

    if (Red::IsInstanceOf<Red::worldPhysicalDestructionNodeInstance>(aNodeInstance))
    {
        return SetRenderProxyVisibility<Raw::WorldPhysicalDestructionNodeInstance::RenderProxy>(aNodeInstance, aToggle, aVisible);
    }

    if (Red::IsInstanceOf<Red::worldInstancedMeshNodeInstance>(aNodeInstance))
    {
        return SetRenderProxyVisibility<Raw::WorldInstancedMeshNodeInstance::RenderProxies>(aNodeInstance, aToggle, aVisible);
    }

    if (Red::IsInstanceOf<Red::worldFoliageNodeInstance>(aNodeInstance))
    {
        return SetRenderProxyVisibility<Raw::WorldFoliageNodeInstance::RenderProxies>(aNodeInstance, aToggle, aVisible);
    }

    if (Red::IsInstanceOf<Red::worldTerrainMeshNodeInstance>(aNodeInstance))
    {
        return SetRenderProxyVisibility<Raw::WorldTerrainMeshNodeInstance::RenderProxies>(aNodeInstance, aToggle, aVisible);
    }

    if (Red::IsInstanceOf<Red::worldStaticLightNodeInstance>(aNodeInstance))
    {
        return SetRenderProxyVisibility<Raw::WorldStaticLightNodeInstance::RenderProxy>(aNodeInstance, aToggle, aVisible);
    }

    return false;
}

template<typename TRenderProxy>
bool App::WorldInspector::SetRenderProxyVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance,
                                                     bool aToggle, bool aVisible)
{
    if constexpr (Red::IsArray<typename TRenderProxy::Type>)
    {
        auto& renderProxies = TRenderProxy::Ref(aNodeInstance);

        if (!renderProxies.size)
            return false;

        for (auto& renderProxy : renderProxies)
        {
            if (aToggle)
                aVisible = !Raw::RenderProxy::IsVisible(renderProxy);

            Raw::RenderProxy::SetVisibility(renderProxy, aVisible);
        }
        return true;
    }
    else
    {
        auto& renderProxy = TRenderProxy::Ref(aNodeInstance);

        if (!renderProxy)
            return false;

        if (aToggle)
            aVisible = !Raw::RenderProxy::IsVisible(renderProxy);

        Raw::RenderProxy::SetVisibility(renderProxy, aVisible);
        return true;
    }
}

bool App::WorldInspector::ApplyHighlightEffect(const Red::Handle<Red::ISerializable>& aObject,
                                                 const Red::Handle<Red::entRenderHighlightEvent>& aEffect)
{
    if (auto& entity = Red::Cast<Red::entEntity>(aObject))
    {
        return SetEntityHighlightEffect(entity, aEffect);
    }

    if (auto& nodeInstance = Red::Cast<Red::worldINodeInstance>(aObject))
    {
        if (Red::IsInstanceOf<Red::worldEntityNodeInstance>(nodeInstance))
        {
            auto& entity = Raw::WorldEntityNodeInstance::Entity::Ref(nodeInstance);
            return SetEntityHighlightEffect(entity, aEffect);
        }

        // if (Red::IsInstanceOf<Red::worldInstancedDestructibleMeshNodeInstance>(nodeInstance))
        // {
        //     return SetRenderProxyHighlightEffect<Raw::WorldInstancedDestructibleMeshNodeInstance::RenderProxy>(nodeInstance, aEffect);
        // }

        if (Red::IsInstanceOf<Red::worldMeshNodeInstance>(nodeInstance))
        {
            return SetRenderProxyHighlightEffect<Raw::WorldMeshNodeInstance::RenderProxy>(nodeInstance, aEffect);
        }

        if (Red::IsInstanceOf<Red::worldStaticDecalNodeInstance>(nodeInstance))
        {
            return SetRenderProxyHighlightEffect<Raw::WorldStaticDecalNodeInstance::RenderProxy>(nodeInstance, aEffect);
        }

        if (Red::IsInstanceOf<Red::worldBendedMeshNodeInstance>(nodeInstance))
        {
            return SetRenderProxyHighlightEffect<Raw::WorldBendedMeshNodeInstance::RenderProxy>(nodeInstance, aEffect);
        }

        if (Red::IsInstanceOf<Red::worldPhysicalDestructionNodeInstance>(nodeInstance))
        {
            return SetRenderProxyHighlightEffect<Raw::WorldPhysicalDestructionNodeInstance::RenderProxy>(nodeInstance, aEffect);
        }

        if (Red::IsInstanceOf<Red::worldInstancedMeshNodeInstance>(nodeInstance))
        {
            return SetRenderProxyHighlightEffect<Raw::WorldInstancedMeshNodeInstance::RenderProxies>(nodeInstance, aEffect);
        }

        if (Red::IsInstanceOf<Red::worldFoliageNodeInstance>(nodeInstance))
        {
            return SetRenderProxyHighlightEffect<Raw::WorldFoliageNodeInstance::RenderProxies>(nodeInstance, aEffect);
        }

        if (Red::IsInstanceOf<Red::worldTerrainMeshNodeInstance>(nodeInstance))
        {
            return SetRenderProxyHighlightEffect<Raw::WorldTerrainMeshNodeInstance::RenderProxies>(nodeInstance, aEffect);
        }
    }

    return false;
}

template<typename TRenderProxy>
bool App::WorldInspector::SetRenderProxyHighlightEffect(const Red::Handle<Red::worldINodeInstance>& aNodeInstance,
                                                          const Red::Handle<Red::entRenderHighlightEvent>& aEffect)
{
    if constexpr (Red::IsArray<typename TRenderProxy::Type>)
    {
        auto& renderProxies = TRenderProxy::Ref(aNodeInstance);

        if (!renderProxies.size)
            return false;

        Red::HighlightParams highlight{aEffect->seeThroughWalls, 0, aEffect->fillIndex, aEffect->outlineIndex,
                                       aEffect->opacity, true};

        for (auto& renderProxy : renderProxies)
        {
            Raw::RenderProxy::SetScanningState(renderProxy, Red::rendPostFx_ScanningState::Complete);
            Raw::RenderProxy::SetHighlightParams(renderProxy, highlight);
        }
        return true;
    }
    else
    {
        auto& renderProxy = TRenderProxy::Ref(aNodeInstance);

        if (!renderProxy)
            return false;

        Red::HighlightParams highlight{aEffect->seeThroughWalls, 0, aEffect->fillIndex, aEffect->outlineIndex,
                                       aEffect->opacity, true};

        Raw::RenderProxy::SetScanningState(renderProxy, Red::rendPostFx_ScanningState::Complete);
        Raw::RenderProxy::SetHighlightParams(renderProxy, highlight);
        return true;
    }
}

bool App::WorldInspector::SetEntityHighlightEffect(const Red::Handle<Red::entEntity>& aEntity,
                                                     const Red::Handle<Red::entRenderHighlightEvent>& aEffect)
{
    if (!aEntity)
        return false;

    aEffect->unk54[0] = 1; // forced
    Red::CallVirtual(aEntity, "QueueEvent", aEffect);

    return true;
}

App::PhysicsTraceResultObject App::WorldInspector::GetPhysicsTraceObject(Red::ScriptRef<Red::physicsTraceResult>& aTrace)
{
    PhysicsTraceResultObject result{};

    if (!aTrace)
        return result;

    auto& resultID = Raw::PhysicsTraceResult::ResultID::Ref(aTrace.ref);

    for (uint32_t i = 0; i < 2; ++i)
    {
        Red::Handle<Red::ISerializable> object;
        Raw::PhysicsTraceResult::GetHitObject(object, resultID, i);

        if (object)
        {
            if (auto nodeInstance = Red::Cast<Red::worldINodeInstance>(object))
            {
                result.nodeInstance = nodeInstance;
                result.nodeDefinition = Raw::WorldNodeInstance::Node::Ref(nodeInstance);
                result.hash = reinterpret_cast<uint64_t>(nodeInstance.instance);
            }
            else if (auto& entity = Red::Cast<Red::entEntity>(object))
            {
                result.entity = entity;
                result.hash = reinterpret_cast<uint64_t>(entity.instance);

                if (entity->entityID.IsStatic())
                {
                    nodeInstance = m_nodeRegistry->FindStreamedNodeInstance(entity->entityID.hash);
                    if (nodeInstance)
                    {
                        result.nodeInstance = nodeInstance;
                        result.nodeDefinition = Raw::WorldNodeInstance::Node::Ref(nodeInstance);
                        result.hash = reinterpret_cast<uint64_t>(nodeInstance.instance);
                    }
                }
            }
            else
            {
                result.hash = reinterpret_cast<uint64_t>(object.instance);
            }

            result.resolved = true;
            break;
        }
    }

    return result;
}

Red::Vector4 App::WorldInspector::ProjectWorldPoint(const Red::Vector4& aPoint)
{
    auto* camera = Raw::CameraSystem::Camera::Ptr(m_cameraSystem);
    auto& point = *reinterpret_cast<const Red::Vector3*>(&aPoint);

    Red::Vector4 result{};
    Raw::Camera::ProjectPoint(camera, result, point);

    return result;
}
