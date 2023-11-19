#include "InspectionSystem.hpp"
#include "Core/Facades/Container.hpp"
#include "Core/Facades/Log.hpp"
#include "Red/CameraSystem.hpp"
#include "Red/Debug.hpp"
#include "Red/Entity.hpp"
#include "Red/Math.hpp"
#include "Red/NodeRef.hpp"
#include "Red/Physics.hpp"
#include "Red/Rendering.hpp"
#include "Red/Transform.hpp"
#include "Red/WorldNode.hpp"

void App::InspectionSystem::OnWorldAttached(Red::world::RuntimeScene*)
{
    m_resourceRegistry = Core::Resolve<ResourceRegistry>();
    m_resourceRegistry->RegisterWatcher(this);

    m_nodeRegistry = Red::GetRuntimeSystem<Red::worldNodeInstanceRegistry>();
    m_cameraSystem = Red::GetGameSystem<Red::gameICameraSystem>();

    m_nodesUpdateDelay = 0;
}

void App::InspectionSystem::OnAfterWorldDetach()
{
    m_resourceRegistry->UnregisterWatcher(this);
    m_resourceRegistry->ClearRuntimeData();

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

void App::InspectionSystem::OnRegisterUpdates(Red::UpdateRegistrar* aRegistrar)
{
    aRegistrar->RegisterUpdate(Red::UpdateTickGroup::FrameBegin, this, "InspectionSystem/UpdateFrustumNodes",
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

void App::InspectionSystem::OnNodeStreamedIn(uint64_t aNodeHash,
                                             Red::worldNode* aNodeDefinition,
                                             Red::worldINodeInstance* aNodeInstance,
                                             Red::CompiledNodeInstanceSetupInfo* aNodeSetup)
{
    std::unique_lock _(m_pendingNodesLock);
    m_pendingNodes.push_back({true, aNodeHash, Red::AsWeakHandle(aNodeInstance),
                              Red::AsWeakHandle(aNodeDefinition), aNodeSetup});
}

void App::InspectionSystem::OnNodeStreamedOut(uint64_t aNodeHash)
{
    // std::unique_lock _(m_streamedNodesLock);
    // m_streamedNodes.erase(aNodeHash);

    std::unique_lock _(m_pendingNodesLock);
    m_pendingNodes.push_back({false, aNodeHash});
}

void App::InspectionSystem::UpdateStreamedNodes()
{
#ifndef NDEBUG
    const auto updateStart = std::chrono::steady_clock::now();
#endif

    Core::Vector<WorldNodeStreamingRequest> pendingNodes;
    {
        std::unique_lock _(m_pendingNodesLock);
        pendingNodes = std::move(m_pendingNodes);
    }

    std::unique_lock _(m_streamedNodesLock);
    for (const auto& [streaming, nodeHash, nodeInstanceWeak, nodeDefinitionWeak, nodeSetup] : pendingNodes)
    {
        if (!streaming)
        {
            m_streamedNodes.erase(nodeHash);
            continue;
        }

        auto nodeInstance = nodeInstanceWeak.Lock();
        auto nodeDefinition = nodeDefinitionWeak.Lock();

        if (!nodeInstance || !nodeDefinition)
            continue;

        WorldNodeStaticSceneData streamedNode{nodeInstanceWeak, nodeDefinitionWeak, nodeSetup};

        auto& transform = Raw::WorldNodeInstance::Transform::Ref(nodeInstance);
        auto& scale = Raw::WorldNodeInstance::Scale::Ref(nodeInstance);

        if (Red::IsInstanceOf<Red::worldMeshNode>(nodeDefinition))
        {
            auto& meshResource = Raw::WorldMeshNodeInstance::Mesh::Ref(nodeInstance);

            if (meshResource)
            {
                Red::Box boundingBox = meshResource->boundingBox;
                Red::ScaleBox(boundingBox, scale);
                Red::TransformBox(boundingBox, transform);

                streamedNode.boundingBoxes.push_back(boundingBox);
                streamedNode.isStaticMesh = !Red::IsInstanceOf<Red::worldTerrainProxyMeshNode>(nodeDefinition) &&
                                            !Red::IsInstanceOf<Red::worldRoadProxyMeshNode>(nodeDefinition);
            }
        }
        else if (Red::IsInstanceOf<Red::worldInstancedMeshNode>(nodeDefinition))
        {
            for (const auto& instanceBox : Raw::WorldInstancedMeshNode::Bounds::Ref(nodeDefinition))
            {
                streamedNode.boundingBoxes.push_back(instanceBox);
                streamedNode.isStaticMesh = true;
            }
        }
        else if (Red::IsInstanceOf<Red::worldStaticDecalNode>(nodeDefinition) ||
                 Red::IsInstanceOf<Red::worldAreaShapeNode>(nodeDefinition) ||
                 Red::IsInstanceOf<Red::worldBendedMeshNode>(nodeDefinition))
        {
            Red::Box boundingBox{};
            Raw::WorldNode::GetBoundingBox(nodeDefinition, boundingBox);

            if (Red::IsValidBox(boundingBox))
            {
                Red::ScaleBox(boundingBox, scale);
                Red::TransformBox(boundingBox, transform);

                streamedNode.boundingBoxes.push_back(boundingBox);
                streamedNode.isStaticMesh = Red::IsInstanceOf<Red::worldStaticDecalNode>(nodeDefinition);
            }
        }
        // else if (Red::IsInstanceOf<Red::worldEntityNode>(aNodeDefinition))
        // {
        // }

        m_streamedNodes.emplace(nodeHash, std::move(streamedNode));
    }

#ifndef NDEBUG
    const std::chrono::duration<double, std::milli> updateDuration = std::chrono::steady_clock::now() - updateStart;
    Core::Log::Debug("UpdateStreamedNodes streamed={} requests={} time={:.3f}ms", m_streamedNodes.size(), pendingNodes.size(), updateDuration.count());
#endif
}

void App::InspectionSystem::UpdateFrustumNodes()
{
    std::chrono::duration<double, std::milli> initDuration{};
    std::chrono::duration<double, std::milli> resolveDuration{};
    std::chrono::duration<double, std::milli> raycastDuration{};
    std::chrono::duration<double, std::milli> commitDuration{};
    const auto updateStart = std::chrono::steady_clock::now();

    Red::DynArray<WorldNodeRuntimeSceneData> frustumNodes{};
    Core::Vector<uint32_t> targetedNodeIndexes{};

    Red::Frustum cameraFrustum;
    Red::Vector4 cameraPosition{};
    Red::Vector4 cameraForward{};

    Raw::CameraSystem::GetCameraPosition(m_cameraSystem, *reinterpret_cast<Red::Vector3*>(&cameraPosition));
    Raw::CameraSystem::GetCameraForward(m_cameraSystem, cameraForward);
    Raw::CameraSystem::GetCameraFrustum(m_cameraSystem, cameraFrustum);

    const Red::Vector4 cameraInverseDirection{1.0f / cameraForward.X, 1.0f / cameraForward.Y, 1.0f / cameraForward.Z};

    initDuration = std::chrono::steady_clock::now() - updateStart;

    {
        std::shared_lock _(m_streamedNodesLock);
        for (const auto& [hash, streamedNode] : m_streamedNodes)
        {
            if (streamedNode.nodeInstance.Expired() || streamedNode.nodeDefinition.Expired())
                continue;

            const auto& transform = streamedNode.nodeSetup->transform;

            if (streamedNode.nodeDefinition.instance->GetType()->GetName() == "worldCompiledCommunityAreaNode_Streamable")
                __nop();

            const auto resolveStart = std::chrono::steady_clock::now();

            Red::FrustumResult frustumResult{};
            Red::Box boundingBox{};

            if (!streamedNode.boundingBoxes.empty())
            {
                for (const auto& candidateBox : streamedNode.boundingBoxes)
                {
                    if ((frustumResult = cameraFrustum.Test(candidateBox)) != Red::FrustumResult::Outside)
                    {
                        boundingBox = candidateBox;
                        break;
                    }
                }
            }
            else
            {
                Red::Box dummyBox{{-0.1, -0.1, -0.1, 1.0}, {0.1, 0.1, 0.1, 1.0}};
                Red::TransformBox(dummyBox, transform);

                frustumResult = cameraFrustum.Test(dummyBox);
            }

            resolveDuration += std::chrono::steady_clock::now() - resolveStart;

            if (frustumResult == Red::FrustumResult::Outside)
                continue;

            const auto raycastStart = std::chrono::steady_clock::now();

            float distance;
            if (Red::IsValidBox(boundingBox) && !Red::IsZeroBox(boundingBox))
            {
                distance = Red::Distance(cameraPosition, boundingBox);
            }
            else
            {
                distance = Red::Distance(cameraPosition, transform.position);
            }

            if (distance > FrustumMaxDistance)
                continue;

            if (streamedNode.isStaticMesh && distance >= 0.001 && distance <= RayCastingMaxDistance)
            {
                if (Red::Intersect(cameraPosition, cameraInverseDirection, boundingBox))
                {
                    targetedNodeIndexes.push_back(frustumNodes.size);
                }
            }

            raycastDuration += std::chrono::steady_clock::now() - raycastStart;

            frustumNodes.PushBack({streamedNode.nodeInstance, streamedNode.nodeDefinition,
                                   transform, boundingBox, distance, hash, true});
        }
    }

    const auto commitStart = std::chrono::steady_clock::now();

    std::sort(targetedNodeIndexes.begin(), targetedNodeIndexes.end(),
              [&frustumNodes](uint32_t a, uint32_t b)
              {
                  return frustumNodes[a].distance < frustumNodes[b].distance;
              });

    {
        std::unique_lock _(m_frustumNodesLock);
        m_frustumNodes = frustumNodes;

        m_targetedNodes.Clear();
        for (const auto& index : targetedNodeIndexes)
        {
            m_targetedNodes.PushBack(frustumNodes[index]);
        }
    }

    commitDuration = std::chrono::steady_clock::now() - commitStart;

    const std::chrono::duration<double, std::milli> updateDuration = std::chrono::steady_clock::now() - updateStart;
    Core::Log::Debug("UpdateFrustumNodes streamed={} frustum={} targets={} "
                     "time={:.3f}ms init={:.3f}ms resolving={:.3f}ms raycasting={:.3f}ms commit={:.3f}ms",
                     m_streamedNodes.size(), m_frustumNodes.size, targetedNodeIndexes.size(),
                     updateDuration.count(), initDuration.count(),
                     resolveDuration.count(), raycastDuration.count(),
                     commitDuration.count());
}

Red::CString App::InspectionSystem::ResolveResourcePath(uint64_t aResourceHash)
{
    return m_resourceRegistry->ResolveResorcePath(aResourceHash);
}

App::WorldNodeStaticData App::InspectionSystem::ResolveSectorDataFromNodeID(uint64_t aNodeID)
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

    return m_resourceRegistry->GetNodeStaticData(aNodeID);
}

App::WorldNodeStaticData App::InspectionSystem::ResolveSectorDataFromNodeInstance(
    const Red::WeakHandle<Red::worldINodeInstance>& aNodeInstance)
{
    return m_resourceRegistry->GetNodeStaticData(aNodeInstance);
}

Red::CString App::InspectionSystem::ResolveNodeRefFromNodeHash(uint64_t aNodeID)
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

uint64_t App::InspectionSystem::ComputeNodeRefHash(const Red::CString& aNodeRef)
{
    return Red::NodeRef(aNodeRef.c_str());
}

Red::EntityID App::InspectionSystem::ResolveCommunityIDFromEntityID(uint64_t aEntityID)
{
    auto entityStubSystem = Red::GetGameSystem<Red::IEntityStubSystem>();
    auto entityStub = entityStubSystem->FindStub(aEntityID);

    if (!entityStub)
        return {};

    return entityStub->stubState->spawnerId.entityId;
}

App::WorldNodeRuntimeSceneData App::InspectionSystem::FindStreamedWorldNode(uint64_t aNodeID)
{
    Red::Handle<Red::worldINodeInstance> nodeInstance;
    Raw::WorldNodeRegistry::FindNode(m_nodeRegistry, nodeInstance, aNodeID);

    if (!nodeInstance)
        return {};

    const auto& [setup, nodeInstanceWeak, nodeDefinitionWeak] = m_resourceRegistry->GetNodeRuntimeData(nodeInstance);

    if (!nodeInstanceWeak)
        return {};

    return {nodeInstanceWeak, nodeDefinitionWeak, setup->transform};
}

Red::DynArray<App::WorldNodeRuntimeSceneData> App::InspectionSystem::GetStreamedWorldNodesInFrustum()
{
    std::shared_lock _(m_frustumNodesLock);
    return m_frustumNodes;
}

Red::DynArray<App::WorldNodeRuntimeSceneData> App::InspectionSystem::GetStreamedWorldNodesInCrosshair()
{
    std::shared_lock _(m_frustumNodesLock);
    return m_targetedNodes;
}

bool App::InspectionSystem::SetNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance, bool aVisible)
{
    return UpdateNodeVisibility(aNodeInstance, false, true);
}

bool App::InspectionSystem::ToggleNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance)
{
    return UpdateNodeVisibility(aNodeInstance, true, true);
}

bool App::InspectionSystem::UpdateNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance,
                                                 bool aToggle, bool aVisible)
{
    if (Red::IsInstanceOf<Red::worldEntityNodeInstance>(aNodeInstance))
    {
        if (aToggle)
            aVisible = !Raw::WorldNodeInstance::IsVisible(aNodeInstance);

        Raw::WorldNodeInstance::SetVisibility(aNodeInstance, aVisible);
        return true;
    }

    if (Red::IsInstanceOf<Red::worldMeshNodeInstance>(aNodeInstance))
    {
        return SetRenderProxyVisibility<Raw::WorldMeshNodeInstance::RenderProxy>(aNodeInstance, aToggle, aVisible);
    }

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

    return false;
}

template<typename TRenderProxy>
bool App::InspectionSystem::SetRenderProxyVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance,
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

bool App::InspectionSystem::ApplyHighlightEffect(const Red::Handle<Red::ISerializable>& aObject,
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

        Red::HighlightParams highlight{aEffect->seeThroughWalls, 0,
                                       aEffect->fillIndex,
                                       aEffect->outlineIndex,
                                       aEffect->opacity,
                                       true};

        if (Red::IsInstanceOf<Red::worldMeshNodeInstance>(nodeInstance))
        {
            return SetRenderProxyHighlightEffect<Raw::WorldMeshNodeInstance::RenderProxy>(nodeInstance, aEffect);
        }

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
bool App::InspectionSystem::SetRenderProxyHighlightEffect(const Red::Handle<Red::worldINodeInstance>& aNodeInstance,
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

        Raw::RenderProxy::SetHighlightParams(renderProxy, highlight);
        return true;
    }
}

bool App::InspectionSystem::SetEntityHighlightEffect(const Red::Handle<Red::entEntity>& aEntity,
                                                     const Red::Handle<Red::entRenderHighlightEvent>& aEffect)
{
    if (!aEntity)
        return false;

    aEffect->unk54[0] = 1; // forced
    Red::CallVirtual(aEntity, "QueueEvent", aEffect);

    return true;
}

Red::DynArray<Red::Handle<Red::IComponent>> App::InspectionSystem::GetComponents(
    const Red::WeakHandle<Red::Entity>& aEntity)
{
    if (aEntity.Expired())
        return {};

    return Raw::Entity::ComponentsStorage::Ptr(aEntity.instance)->components;
}

Red::ResourceAsyncReference<> App::InspectionSystem::GetTemplatePath(const Red::WeakHandle<Red::Entity>& aEntity)
{
    if (aEntity.Expired())
        return {};

    return Raw::Entity::TemplatePath::Ref(aEntity.instance);
}

App::PhysicsTraceResultObject App::InspectionSystem::GetPhysicsTraceObject(Red::ScriptRef<Red::physicsTraceResult>& aTrace)
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
            }
            else if (auto& entity = Red::Cast<Red::entEntity>(object))
            {
                result.entity = entity;

                const auto& entityID = Raw::Entity::EntityID::Ref(entity.instance);
                if (entityID.IsStatic())
                {
                    Raw::WorldNodeRegistry::FindNode(m_nodeRegistry, nodeInstance, entityID.hash);
                    if (nodeInstance)
                    {
                        result.nodeInstance = nodeInstance;
                        result.nodeDefinition = Raw::WorldNodeInstance::Node::Ref(nodeInstance);
                    }
                }
            }

            result.hash = reinterpret_cast<uint64_t>(object.instance);
            result.resolved = true;
            break;
        }
    }

    return result;
}

Red::Vector4 App::InspectionSystem::ProjectWorldPoint(const Red::Vector4& aPoint)
{
    auto* camera = Raw::CameraSystem::Camera::Ptr(m_cameraSystem);
    auto& point = *reinterpret_cast<const Red::Vector3*>(&aPoint);

    Red::Vector4 result{};
    Raw::Camera::ProjectPoint(camera, result, point);

    return result;
}

Red::CName App::InspectionSystem::GetTypeName(const Red::WeakHandle<Red::ISerializable>& aInstace)
{
    if (!aInstace)
        return {};

    return aInstace.instance->GetType()->GetName();
}

bool App::InspectionSystem::IsInstanceOf(const Red::WeakHandle<Red::ISerializable>& aInstace, Red::CName aType)
{
    return aInstace && aInstace.instance->GetType()->IsA(Red::GetType(aType));
}

uint64_t App::InspectionSystem::GetObjectHash(const Red::WeakHandle<Red::ISerializable>& aInstace)
{
    return reinterpret_cast<uint64_t>(aInstace.instance);
}
