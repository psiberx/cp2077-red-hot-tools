#include "WorldInspector.hpp"
#include "Core/Facades/Container.hpp"
#include "Core/Facades/Log.hpp"
#include "Red/CameraSystem.hpp"
#include "Red/CommunitySystem.hpp"
#include "Red/Debug.hpp"
#include "Red/Math.hpp"
#include "Red/Physics.hpp"
#include "Red/Rendering.hpp"
#include "Red/StreamingSystem.hpp"
#include "Red/Transform.hpp"
#include "Red/WorldNode.hpp"

void App::WorldInspector::OnInitialize(const Red::JobHandle& aJob)
{
    HookBefore<Raw::StreamingSystem::CollectNodeParallel>(&OnCollectNodeParallel);
}

void App::WorldInspector::OnWorldAttached(Red::world::RuntimeScene*)
{
    m_nodeRegistry = Core::Resolve<WorldNodeRegistry>();
    m_nodeRegistry->RegisterWatcher(this);

    m_cameraSystem = Red::GetGameSystem<Red::gameICameraSystem>();

    m_nodesUpdateDelay = 0;
}

void App::WorldInspector::OnAfterWorldDetach()
{
    m_ready = false;

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

void App::WorldInspector::OnGamePrepared()
{
    m_ready = true;
}

void App::WorldInspector::OnRegisterUpdates(Red::UpdateRegistrar* aRegistrar)
{
    aRegistrar->RegisterUpdate(Red::UpdateTickGroup::FrameBegin, this, "WorldInspector/UpdateNodes",
                               [this](Red::FrameInfo& aFrame, Red::JobQueue&)
                               {
                                   if (m_ready && !m_nodesUpdating)
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

        if (!nodeDefinition.instance->isVisibleInGame)
        {
            continue;
        }

        WorldNodeStaticSceneData streamedNode{request.nodeInstance, request.nodeDefinition,
                                              request.nodeSetup->transform.position,
                                              request.nodeSetup->transform.orientation,
                                              request.nodeSetup->scale,
                                              (request.nodeSetup->unk7A & 0x40) == 0x40};

        auto& nodeTransform = Raw::WorldNodeInstance::Transform::Ref(nodeInstance);
        auto& nodeScale = Raw::WorldNodeInstance::Scale::Ref(nodeInstance);

        if (Red::IsInstanceOf<Red::worldInstancedMeshNode>(nodeDefinition))
        {
            auto& meshResource = Raw::WorldInstancedMeshNodeInstance::Mesh::Ref(nodeInstance);

            if (meshResource)
            {
                auto& meshNode = Red::Cast<Red::worldInstancedMeshNode>(nodeDefinition);
                auto& meshBuffer = meshNode->worldTransformsBuffer;
                auto* meshInstances = std::bit_cast<Red::RenderProxyTransformData*>(&meshBuffer.sharedDataBuffer->buffer);

                streamedNode.actors.reserve(meshBuffer.numElements);

                for (auto i = 0; i < meshBuffer.numElements; ++i)
                {
                    auto* meshInstance = meshInstances->Get(meshBuffer.startIndex + i);
                    auto& nodeActor = streamedNode.actors.emplace_back();

                    nodeActor.position = meshInstance->transform.Position;
                    nodeActor.orientation = meshInstance->transform.Orientation;
                    nodeActor.boundingBox = meshResource->boundingBox;

                    Red::ScaleBox(nodeActor.boundingBox, meshInstance->scale);

                    nodeActor.testBox = nodeActor.boundingBox;

                    Red::TransformBox(nodeActor.testBox, {nodeActor.position, nodeActor.orientation});
                }

                streamedNode.isTargetable = true;
            }
            else
            {
                postponedRequests[hash] = request;
                continue;
            }
        }
        else if (Red::IsInstanceOf<Red::worldInstancedOccluderNode>(nodeDefinition))
        {
            auto& meshResource = Raw::WorldInstancedOccluderNodeInstance::Mesh::Ref(nodeInstance);

            if (meshResource)
            {
                auto& occluderNode = Red::Cast<Red::worldInstancedOccluderNode>(nodeDefinition);
                auto& occluderInstances = Raw::WorldInstancedOccluderNode::Instances::Ref(nodeDefinition);

                streamedNode.actors.reserve(occluderInstances.Size());

                for (auto i = 0; i < occluderInstances.Size(); ++i)
                {
                    auto& occluderMatrix = occluderInstances[i];
                    auto& nodeActor = streamedNode.actors.emplace_back();

                    Red::CallStatic("Matrix", "GetTranslation", nodeActor.position, occluderMatrix);
                    Red::CallStatic("Matrix", "ToQuat", nodeActor.orientation, occluderMatrix);

                    nodeActor.boundingBox = meshResource->boundingBox;

                    Red::Vector4 occluderScale;
                    Red::CallStatic("Matrix", "GetScale", occluderScale, occluderMatrix);
                    Red::ScaleBox(nodeActor.boundingBox, occluderScale);

                    nodeActor.testBox = nodeActor.boundingBox;

                    Red::TransformBox(nodeActor.testBox, {nodeActor.position, nodeActor.orientation});
                }

                streamedNode.isTargetable = true;
            }
            else
            {
                postponedRequests[hash] = request;
                continue;
            }
        }
        else if (Red::IsInstanceOf<Red::worldFoliageNode>(nodeDefinition))
        {
            auto& meshResource = Raw::WorldFoliageNodeInstance::Mesh::Ref(nodeInstance);
            auto& foliageResource = Raw::WorldFoliageNodeInstance::Foliage::Ref(nodeInstance);

            if (meshResource && foliageResource)
            {
                auto& foliageNode = Red::Cast<Red::worldFoliageNode>(nodeDefinition);
                auto instanceOffset = foliageNode->populationSpanInfo.stancesBegin;
                auto instanceCount = foliageNode->populationSpanInfo.stancesCount;

                streamedNode.actors.reserve(instanceCount);

                auto foliageBuffer = Red::FoliageBufferAccessor(foliageResource);

                for (auto i = 0; i < instanceCount; ++i)
                {
                    auto& nodeActor = streamedNode.actors.emplace_back();
                    auto instanceIndex = instanceOffset + i;

                    nodeActor.position = nodeTransform.position + foliageBuffer.GetPosition(instanceIndex);
                    nodeActor.orientation = foliageBuffer.GetOrientation(instanceIndex);
                    nodeActor.boundingBox = meshResource->boundingBox;

                    auto instanceScale = foliageBuffer.GetScale(instanceIndex);
                    Red::ScaleBox(nodeActor.boundingBox, {instanceScale, instanceScale, instanceScale});

                    nodeActor.testBox = nodeActor.boundingBox;

                    Red::TransformBox(nodeActor.testBox, {nodeActor.position, nodeActor.orientation});
                }

                streamedNode.isTargetable = true;
            }
            else
            {
                postponedRequests[hash] = request;
                continue;
            }
        }
        else if (Red::IsInstanceOf<Red::worldBakedDestructionNode>(nodeDefinition) ||
                 Red::IsInstanceOf<Red::worldInstancedDestructibleMeshNode>(nodeDefinition))
        {
            // Treat as dynamic
        }
        else if (Red::IsInstanceOf<Red::worldMeshNode>(nodeDefinition))
        {
            auto& meshResource = Raw::WorldMeshNodeInstance::Mesh::Ref(nodeInstance);

            if (meshResource)
            {
                auto& actor = streamedNode.actors.emplace_back();

                actor.position = nodeTransform.position;
                actor.orientation = nodeTransform.orientation;
                actor.boundingBox = meshResource->boundingBox;

                Red::ScaleBox(actor.boundingBox, nodeScale);

                actor.testBox = actor.boundingBox;

                Red::TransformBox(actor.testBox, nodeTransform);

                streamedNode.isTargetable = true;
            }
            else
            {
                postponedRequests[hash] = request;
                continue;
            }
        }
        else if (Red::IsInstanceOf<Red::worldBendedMeshNode>(nodeDefinition))
        {
            auto& bendedNode = Red::Cast<Red::worldBendedMeshNode>(nodeDefinition);

            auto& actor = streamedNode.actors.emplace_back();

            actor.position = nodeTransform.position;
            actor.orientation = nodeTransform.orientation;
            actor.boundingBox = bendedNode->deformedBox;

            Red::ScaleBox(actor.boundingBox, nodeScale);

            actor.testBox = actor.boundingBox;

            Red::TransformBox(actor.testBox, nodeTransform);

            streamedNode.isTargetable = true;
        }
        else if (Red::IsInstanceOf<Red::worldTerrainMeshNode>(nodeDefinition))
        {
            auto& meshResource = Raw::WorldTerrainMeshNodeInstance::Mesh::Ref(nodeInstance);

            if (meshResource)
            {
                auto& actor = streamedNode.actors.emplace_back();

                actor.position = nodeTransform.position;
                actor.orientation = nodeTransform.orientation;
                actor.boundingBox = meshResource->boundingBox;

                Red::ScaleBox(actor.boundingBox, nodeScale);

                actor.testBox = actor.boundingBox;

                Red::TransformBox(actor.testBox, nodeTransform);

                streamedNode.isTargetable = true;
            }
            else
            {
                postponedRequests[hash] = request;
                continue;
            }
        }
        // else if (Red::IsInstanceOf<Red::worldStaticParticleNode>(nodeDefinition))
        // {
        //     auto& particleResource = Raw::WorldStaticParticleNodeInstance::ParticleSystem::Ref(nodeInstance);
        //
        //     if (particleResource)
        //     {
        //         auto& actor = streamedNode.actors.emplace_back();
        //
        //         actor.position = nodeTransform.position;
        //         actor.orientation = nodeTransform.orientation;
        //         actor.boundingBox = particleResource->boundingBox;
        //
        //         Red::ScaleBox(actor.boundingBox, nodeScale);
        //
        //         actor.testBox = actor.boundingBox;
        //
        //         Red::TransformBox(actor.testBox, nodeTransform);
        //
        //         streamedNode.isTargetable = true;
        //     }
        //     else
        //     {
        //         postponedRequests[hash] = request;
        //         continue;
        //     }
        // }
        else if (Red::IsInstanceOf<Red::worldStaticDecalNode>(nodeDefinition) ||
                 Red::IsInstanceOf<Red::worldStaticOccluderMeshNode>(nodeDefinition) ||
                 Red::IsInstanceOf<Red::worldReflectionProbeNode>(nodeDefinition) ||
                 Red::IsInstanceOf<Red::worldGeometryShapeNode>(nodeDefinition) ||
                 Red::IsInstanceOf<Red::worldAreaShapeNode>(nodeDefinition))
        {
            Red::Box nodeBoundingBox{{1.0, 0.0, 0.0, 0.0}, {-1.0, 0.0, 0.0, 0.0}};
            Raw::WorldNode::GetBoundingBox(nodeDefinition, nodeBoundingBox);

            if (Red::IsValidBox(nodeBoundingBox))
            {
                auto& actor = streamedNode.actors.emplace_back();

                actor.position = nodeTransform.position;
                actor.orientation = nodeTransform.orientation;
                actor.boundingBox = nodeBoundingBox;

                Red::ScaleBox(actor.boundingBox, nodeScale);

                actor.testBox = actor.boundingBox;

                Red::TransformBox(actor.testBox, nodeTransform);

                streamedNode.isTargetable = !Red::IsInstanceOf<Red::worldGeometryShapeNode>(nodeDefinition) &&
                                            !Red::IsInstanceOf<Red::worldAreaShapeNode>(nodeDefinition) &&
                                            !Red::IsInstanceOf<Red::worldWaterPatchNode>(nodeDefinition);
            }
            else
            {
                postponedRequests[hash] = request;
                continue;
            }
        }
        else if (Red::IsInstanceOf<Red::worldStaticLightNode>(nodeDefinition))
        {
            auto& actor = streamedNode.actors.emplace_back();

            actor.position = nodeTransform.position;
            actor.orientation = nodeTransform.orientation;
            actor.boundingBox = {{-0.3, -0.3, -0.3, 1.0}, {0.3, 0.3, 0.3, 1.0}};

            Red::ScaleBox(actor.boundingBox, nodeScale);

            actor.testBox = actor.boundingBox;

            Red::TransformBox(actor.testBox, nodeTransform);

            streamedNode.isTargetable = true;
        }
        else if (Red::IsInstanceOf<Red::worldStaticParticleNode>(nodeDefinition))
        {
            auto& actor = streamedNode.actors.emplace_back();

            actor.position = nodeTransform.position;
            actor.orientation = nodeTransform.orientation;
            actor.boundingBox = {{-0.5, -0.5, -0.25, 1.0}, {0.5, 0.5, 0.25, 1.0}};

            Red::ScaleBox(actor.boundingBox, nodeScale);

            actor.testBox = actor.boundingBox;

            Red::TransformBox(actor.testBox, nodeTransform);

            streamedNode.isTargetable = true;
        }
        else if (Red::IsInstanceOf<Red::worldAISpotNode>(nodeDefinition))
        {
            auto& actor = streamedNode.actors.emplace_back();

            actor.position = nodeTransform.position;
            actor.orientation = nodeTransform.orientation;
            actor.boundingBox = {{-0.5, -0.5, 0, 1.0}, {0.5, 0.5, 0.05, 1.0}};

            Red::ScaleBox(actor.boundingBox, nodeScale);

            actor.testBox = actor.boundingBox;

            Red::TransformBox(actor.testBox, nodeTransform);

            streamedNode.isTargetable = true;
        }
        else if (Red::IsInstanceOf<Red::worldCollisionNode>(nodeDefinition))
        {
            // TODO: Add actors for static scanning
        }
        else if (Red::IsInstanceOf<Red::worldTerrainCollisionNode>(nodeDefinition))
        {
            // TODO: Add actors for static scanning
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
    std::chrono::duration<double, std::milli> commitDuration{};
    std::chrono::duration<double, std::milli> frustumDuration{};
    std::chrono::duration<double, std::milli> raycastDuration{};
    std::chrono::duration<double, std::milli> collectDuration{};
    const auto functionStart = std::chrono::steady_clock::now();
#endif

    Core::Vector<WorldNodeRuntimeSceneData> frustumNodes{};
    Core::Vector<uint32_t> targetedNodeIndexes{};

    {
        std::shared_lock _(m_frustumNodesLock);
        frustumNodes.reserve(m_frustumNodes.Size());
        targetedNodeIndexes.reserve(m_targetedNodes.Size());
    }

    Red::Frustum cameraFrustum;
    Red::Vector4 cameraPosition{};
    Red::Vector4 cameraForward{};

    Raw::CameraSystem::GetCameraPosition(m_cameraSystem, *reinterpret_cast<Red::Vector3*>(&cameraPosition));
    Raw::CameraSystem::GetCameraForward(m_cameraSystem, cameraForward);
    Raw::CameraSystem::GetCameraFrustum(m_cameraSystem, cameraFrustum);

    const Red::Box invalidBox{{1.0, 0.0, 0.0, 0.0}, {-1.0, 0.0, 0.0, 0.0}};

#ifndef NDEBUG
    initDuration = std::chrono::steady_clock::now() - functionStart;
#endif

    {
        std::shared_lock _(m_streamedNodesLock);

        Core::Vector<int32_t> frustumActorIndexes;

        for (const auto& [hash, streamedNode] : m_streamedNodes)
        {
            if (streamedNode.nodeInstance.Expired() || streamedNode.nodeDefinition.Expired())
                continue;

#ifndef NDEBUG
            const auto frustumStart = std::chrono::steady_clock::now();
#endif

            Red::FrustumResult frustumResult{};

            if (!streamedNode.actors.empty())
            {
                frustumActorIndexes.clear();

                for (auto candidateActorIndex = 0; candidateActorIndex < streamedNode.actors.size(); ++candidateActorIndex)
                {
                    const auto& candidateActor = streamedNode.actors[candidateActorIndex];
                    const auto candidateResult = cameraFrustum.Test(candidateActor.testBox);

                    if (candidateResult != Red::FrustumResult::Outside)
                    {
                        frustumActorIndexes.push_back(candidateActorIndex);
                        frustumResult = candidateResult;
                    }
                }
            }
            else
            {
                Red::Box testBox{{-0.05, -0.05, -0.05, 1.0}, {0.05, 0.05, 0.05, 1.0}};
                Red::TransformBox(testBox, {streamedNode.position, streamedNode.orientation});

                frustumResult = cameraFrustum.Test(testBox);
            }

#ifndef NDEBUG
            frustumDuration += std::chrono::steady_clock::now() - frustumStart;
#endif

            if (frustumResult != Red::FrustumResult::Inside && frustumResult != Red::FrustumResult::Intersecting && !m_discoverMode)
                continue;

#ifndef NDEBUG
            const auto raycastStart = std::chrono::steady_clock::now();
#endif

            float nearestDistance = std::numeric_limits<float>::max();
            int32_t nearestActorIndex = -1;
            int32_t overlapActorIndex = -1;

            if (!streamedNode.actors.empty() && !frustumActorIndexes.empty())
            {
                int32_t targetActorIndex = -1;

                for (const auto candidateActorIndex : frustumActorIndexes)
                {
                    const auto& candidateActor = streamedNode.actors[candidateActorIndex];

                    Red::Quaternion inverseRotation = candidateActor.orientation.Inverse();
                    Red::Vector4 localPosition = (cameraPosition - candidateActor.position) * inverseRotation;

                    if (Red::InsideBox(localPosition, candidateActor.boundingBox))
                    {
                        if (overlapActorIndex == -1)
                        {
                            overlapActorIndex = candidateActorIndex;
                        }
                        continue;
                    }

                    auto candidateDistance = Red::Distance(localPosition, candidateActor.boundingBox);

                    if (candidateDistance > m_frustumDistance && !m_discoverMode)
                        continue;

                    auto targeted = false;
                    if (streamedNode.isTargetable)
                    {
                        // Red::Vector4 localForward = cameraForward;
                        // Red::CallStatic("Quaternion", "Transform", localForward, inverseRotation, localForward);
                        Red::Vector4 localForward = cameraForward * inverseRotation;
                        Red::Vector4 inverseForward{1.0f / localForward.X, 1.0f / localForward.Y, 1.0f / localForward.Z, 0.0};

                        targeted = Red::IntersectBox(localPosition, inverseForward, candidateActor.boundingBox);
                    }

                    if (targeted)
                    {
                        if (targetActorIndex == -1 || candidateDistance < nearestDistance)
                        {
                            targetActorIndex = candidateActorIndex;
                            nearestActorIndex = candidateActorIndex;
                            nearestDistance = candidateDistance;
                        }
                    }
                    else
                    {
                        if (targetActorIndex == -1 && candidateDistance < nearestDistance)
                        {
                            nearestActorIndex = candidateActorIndex;
                            nearestDistance = candidateDistance;
                        }
                    }
                }

                if (targetActorIndex != -1)
                {
                    if (nearestDistance <= m_targetingDistance)
                    {
                        targetedNodeIndexes.push_back(frustumNodes.size());
                    }
                }
                else if (overlapActorIndex != -1)
                {
                    if (streamedNode.isTargetable)
                    {
                        targetActorIndex = overlapActorIndex;
                        targetedNodeIndexes.push_back(frustumNodes.size());
                    }

                    nearestActorIndex = overlapActorIndex;
                    nearestDistance = 0.0;
                }
            }
            else
            {
                nearestDistance = Red::Distance(cameraPosition, streamedNode.position);
            }

#ifndef NDEBUG
            raycastDuration += std::chrono::steady_clock::now() - raycastStart;
#endif

            if (nearestDistance > m_frustumDistance && !m_discoverMode)
                continue;

#ifndef NDEBUG
            const auto collecttStart = std::chrono::steady_clock::now();
#endif

            const auto nodeHash = reinterpret_cast<uint64_t>(streamedNode.nodeInstance.instance);
            const bool nodeEnabled = Raw::WorldNodeInstance::State::Ref(streamedNode.nodeInstance.instance).isVisible;
            const auto* nearestActor = nearestActorIndex != -1 ? &streamedNode.actors[nearestActorIndex] : nullptr;

            frustumNodes.push_back({streamedNode.nodeInstance,
                                    streamedNode.nodeDefinition,
                                    nearestActor ? nearestActor->position : streamedNode.position,
                                    nearestActor ? nearestActor->orientation : streamedNode.orientation,
                                    streamedNode.scale,
                                    nearestActor ? nearestActor->boundingBox : invalidBox,
                                    nearestActor ? nearestActor->testBox : invalidBox,
                                    nearestActorIndex,
                                    static_cast<uint32_t>(streamedNode.actors.size()),
                                    nearestDistance,
                                    streamedNode.interior,
                                    nodeEnabled,
                                    nodeHash,
                                    true});

#ifndef NDEBUG
            collectDuration += std::chrono::steady_clock::now() - collecttStart;
#endif
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

    const auto resolveDuration = frustumDuration + raycastDuration + collectDuration;
    const auto updateDuration = initDuration + resolveDuration + commitDuration;

    const std::chrono::duration<double, std::milli> functionDuration = std::chrono::steady_clock::now() - functionStart;
    const auto measurementCost = functionDuration - updateDuration;

    Core::Log::Debug("UpdateFrustumNodes streamed={} frustum={} targets={} "
                     "time={:.3f}ms init={:.3f}ms resolve={:.3f}ms "
                     "(frustum={:.3f}ms raycast={:.3f}ms collect={:.3f}ms) "
                     "commit={:.3f}ms ",
                     m_streamedNodes.size(), m_frustumNodes.size, targetedNodeIndexes.size(),
                     updateDuration.count(), initDuration.count(), resolveDuration.count(),
                     frustumDuration.count(), raycastDuration.count(), collectDuration.count(),
                     commitDuration.count());
#endif
}

bool App::WorldInspector::IsReady() const
{
    return m_ready;
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
    m_targetingDistance = std::clamp(aDistance, TargetingMinDistance, m_frustumDistance);
}

bool App::WorldInspector::IsDiscoverMode() const
{
    return m_discoverMode;
}

void App::WorldInspector::SetDiscoverMode(bool aEnabled)
{
    m_discoverMode = aEnabled;
}

App::WorldNodeInstanceStaticData App::WorldInspector::ResolveSectorDataFromNodeID(uint64_t aNodeID)
{
    if (!m_ready)
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

    return m_nodeRegistry->GetNodeStaticData(aNodeID);
}

App::WorldNodeInstanceStaticData App::WorldInspector::ResolveSectorDataFromNodeInstance(
    const Red::WeakHandle<Red::worldINodeInstance>& aNodeInstance)
{
    if (!m_ready)
        return {};

    return m_nodeRegistry->GetNodeStaticData(aNodeInstance);
}

Red::CString App::WorldInspector::ResolveNodeRefFromNodeHash(uint64_t aNodeID)
{
    if (!m_ready || !aNodeID)
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
    if (!m_ready)
        return {};

    auto entityStubSystem = Red::GetGameSystem<Red::IEntityStubSystem>();
    auto entityStub = entityStubSystem->FindStub(aEntityID);

    if (!entityStub)
        return {};

    return entityStub->stubState->spawnerId.entityId;
}

App::WorldCommunityEntryData App::WorldInspector::ResolveCommunityEntryDataFromEntityID(uint64_t aEntityID)
{
    if (!m_ready)
        return {};

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
        communityEntryData.registryIndex = communitySectorData.registryIndex;
        communityEntryData.communityIndex = communitySectorData.communityIndex;
        communityEntryData.communityCount = communitySectorData.communityCount;
        communityEntryData.communityID = communitySectorData.communityID;
    }
    else
    {
        communityEntryData.communityID = communityID;
    }

    const auto communityEntryCount = community.instance->entries.Size();
    for (auto communityEntryIndex = 0; communityEntryIndex < communityEntryCount; ++communityEntryIndex)
    {
        const auto& communityEntry = community.instance->entries[communityEntryIndex];
        if (communityEntry->name == communityEntryName)
        {
            communityEntryData.entryName = communityEntryName;
            communityEntryData.entryIndex = communityEntryIndex;
            communityEntryData.entryCount = communityEntryCount;

            if (communityEntry->unk2C >= 0 && communityEntry->unk2C < communityEntry->phases.Size())
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
    if (!m_ready)
        return {};

    auto nodeInstance = m_nodeRegistry->FindStreamedNodeInstance(aNodeID);

    if (!nodeInstance)
        return {};

    const auto& [setup, nodeInstanceWeak, nodeDefinitionWeak] = m_nodeRegistry->GetNodeRuntimeData(nodeInstance);

    if (!nodeInstanceWeak)
        return {};

    return {nodeInstanceWeak, nodeDefinitionWeak, setup->transform.position, setup->transform.orientation};
}

Red::DynArray<App::WorldNodeRuntimeSceneData> App::WorldInspector::GetStreamedNodesInFrustum()
{
    if (!m_ready)
        return {};

    std::shared_lock _(m_frustumNodesLock);
    return m_frustumNodes;
}

Red::DynArray<App::WorldNodeRuntimeSceneData> App::WorldInspector::GetStreamedNodesInCrosshair()
{
    if (!m_ready)
        return {};

    std::shared_lock _(m_frustumNodesLock);
    return m_targetedNodes;
}

App::WorldNodeRuntimeGeometryData App::WorldInspector::GetStreamedNodeGeometry(
    const Red::WeakHandle<Red::worldINodeInstance>& aNode)
{
    if (!m_ready)
        return {};

    const auto& [setup, nodeInstanceWeak, nodeDefinitionWeak] = m_nodeRegistry->GetNodeRuntimeData(aNode);

    if (!setup)
        return {};

    return {setup->transform.position, setup->transform.orientation, setup->scale};
}

bool App::WorldInspector::SetNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance, bool aVisible)
{
    if (!m_ready)
        return false;

    return UpdateNodeVisibility(aNodeInstance, false, true);
}

bool App::WorldInspector::ToggleNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance)
{
    if (!m_ready)
        return false;

    return UpdateNodeVisibility(aNodeInstance, true, true);
}

bool App::WorldInspector::GetNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance) const
{
    if (!m_ready)
        return false;

    return Raw::WorldNodeInstance::IsVisible(aNodeInstance);
    // return GetRenderProxyVisibility(aNodeInstance);
}

bool App::WorldInspector::UpdateNodeVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance,
                                               bool aToggle, bool aVisible)
{
    if (!m_ready)
        return false;

    if (aToggle)
    {
        aVisible = !Raw::WorldNodeInstance::IsVisible(aNodeInstance);
        aToggle = false;
    }

    Raw::WorldNodeInstance::SetVisibility(aNodeInstance, aVisible);

    if (Red::IsInstanceOf<Red::worldEntityNodeInstance>(aNodeInstance))
    {
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

    if (Red::IsInstanceOf<Red::worldStaticParticleNodeInstance>(aNodeInstance))
    {
        return SetRenderProxyVisibility<Raw::WorldStaticParticleNodeInstance::RenderProxy>(aNodeInstance, aToggle, aVisible);
    }

    return false;
}

template<typename TRenderProxy>
bool App::WorldInspector::SetRenderProxyVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance,
                                                   bool aToggle, bool aVisible)
{
    if (!m_ready)
        return false;

    if constexpr (Red::IsArray<typename TRenderProxy::Type>)
    {
        auto& renderProxies = TRenderProxy::Ref(aNodeInstance);

        if (renderProxies.IsEmpty())
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

bool App::WorldInspector::GetRenderProxyVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance) const
{
    if (!m_ready)
        return false;

    // if (Red::IsInstanceOf<Red::worldEntityNodeInstance>(aNodeInstance))
    // {
    //     return Raw::WorldNodeInstance::IsVisible(aNodeInstance);
    // }

    // if (Red::IsInstanceOf<Red::worldInstancedDestructibleMeshNodeInstance>(aNodeInstance))
    // {
    //     return GetRenderProxyVisibility<Raw::WorldInstancedDestructibleMeshNodeInstance::RenderProxy>(aNodeInstance);
    // }

    if (Red::IsInstanceOf<Red::worldMeshNodeInstance>(aNodeInstance))
    {
        return GetRenderProxyVisibility<Raw::WorldMeshNodeInstance::RenderProxy>(aNodeInstance);
    }

    if (Red::IsInstanceOf<Red::worldStaticDecalNodeInstance>(aNodeInstance))
    {
        return GetRenderProxyVisibility<Raw::WorldStaticDecalNodeInstance::RenderProxy>(aNodeInstance);
    }

    if (Red::IsInstanceOf<Red::worldBendedMeshNodeInstance>(aNodeInstance))
    {
        return GetRenderProxyVisibility<Raw::WorldBendedMeshNodeInstance::RenderProxy>(aNodeInstance);
    }

    if (Red::IsInstanceOf<Red::worldPhysicalDestructionNodeInstance>(aNodeInstance))
    {
        return GetRenderProxyVisibility<Raw::WorldPhysicalDestructionNodeInstance::RenderProxy>(aNodeInstance);
    }

    if (Red::IsInstanceOf<Red::worldInstancedMeshNodeInstance>(aNodeInstance))
    {
        return GetRenderProxyVisibility<Raw::WorldInstancedMeshNodeInstance::RenderProxies>(aNodeInstance);
    }

    if (Red::IsInstanceOf<Red::worldFoliageNodeInstance>(aNodeInstance))
    {
        return GetRenderProxyVisibility<Raw::WorldFoliageNodeInstance::RenderProxies>(aNodeInstance);
    }

    if (Red::IsInstanceOf<Red::worldTerrainMeshNodeInstance>(aNodeInstance))
    {
        return GetRenderProxyVisibility<Raw::WorldTerrainMeshNodeInstance::RenderProxies>(aNodeInstance);
    }

    if (Red::IsInstanceOf<Red::worldStaticLightNodeInstance>(aNodeInstance))
    {
        return GetRenderProxyVisibility<Raw::WorldStaticLightNodeInstance::RenderProxy>(aNodeInstance);
    }

    return Raw::WorldNodeInstance::IsVisible(aNodeInstance);
}

template<typename TRenderProxy>
bool App::WorldInspector::GetRenderProxyVisibility(const Red::Handle<Red::worldINodeInstance>& aNodeInstance) const
{
    if (!m_ready)
        return false;

    if constexpr (Red::IsArray<typename TRenderProxy::Type>)
    {
        auto& renderProxies = TRenderProxy::Ref(aNodeInstance);

        if (renderProxies.IsEmpty())
            return false;

        for (auto& renderProxy : renderProxies)
        {
            if (Raw::RenderProxy::IsVisible(renderProxy))
            {
                return true;
            }
        }

        return true;
    }
    else
    {
        auto& renderProxy = TRenderProxy::Ref(aNodeInstance);

        if (!renderProxy)
            return false;

        return Raw::RenderProxy::IsVisible(renderProxy);
    }
}

bool App::WorldInspector::ApplyHighlightEffect(const Red::Handle<Red::ISerializable>& aObject,
                                                 const Red::Handle<Red::entRenderHighlightEvent>& aEffect)
{
    if (!m_ready)
        return false;

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
    if (!m_ready)
        return false;

    if constexpr (Red::IsArray<typename TRenderProxy::Type>)
    {
        auto& renderProxies = TRenderProxy::Ref(aNodeInstance);

        if (renderProxies.IsEmpty())
            return false;

        EnhanceHighlightEffect(aEffect);

        Red::HighlightParams highlight{aEffect->seeThroughWalls, 0, aEffect->fillIndex, aEffect->outlineIndex,
                                       aEffect->opacity, true};

        for (auto& renderProxy : renderProxies)
        {
            Raw::RenderProxy::SetHighlightParams(renderProxy, highlight);
            Raw::RenderProxy::SetScanningState(renderProxy, Red::rendPostFx_ScanningState::Complete);
        }

        return true;
    }
    else
    {
        auto& renderProxy = TRenderProxy::Ref(aNodeInstance);

        if (!renderProxy)
            return false;

        EnhanceHighlightEffect(aEffect);

        Red::HighlightParams highlight{aEffect->seeThroughWalls, 0, aEffect->fillIndex, aEffect->outlineIndex,
                                       aEffect->opacity, true};

        Raw::RenderProxy::SetHighlightParams(renderProxy, highlight);
        Raw::RenderProxy::SetScanningState(renderProxy, Red::rendPostFx_ScanningState::Complete);

        return true;
    }
}

bool App::WorldInspector::SetEntityHighlightEffect(const Red::Handle<Red::entEntity>& aEntity,
                                                   const Red::Handle<Red::entRenderHighlightEvent>& aEffect) const
{
    if (!aEntity)
        return false;

    EnhanceHighlightEffect(aEffect);

    aEffect->unk54[0] = 1; // forced
    aEffect->unk54[1] = 0; // patternType
    Red::CallVirtual(aEntity, "QueueEvent", aEffect);

    return true;
}

void App::WorldInspector::EnhanceHighlightEffect(const Red::Handle<Red::entRenderHighlightEvent>& aEffect) const
{
    auto visionModeSystem = Red::GetGameSystem<Red::gameIVisionModeSystem>();
    Raw::VisionModeSystem::SetBraindanceMode(visionModeSystem, (aEffect->outlineIndex || aEffect->fillIndex) ? 1 : 0);
}

App::PhysicsTraceResultObject App::WorldInspector::GetPhysicsTraceObject(Red::ScriptRef<Red::physicsTraceResult>& aTrace)
{
    PhysicsTraceResultObject result{};

    if (!aTrace)
        return result;

    auto trace = aTrace.ref;

    for (uint32_t i = 0; i < 2; ++i)
    {
        Red::Handle<Red::ISerializable> object;
        Raw::PhysicsProxy::GetHitObject(object, trace->proxyID, i);

        if (object)
        {
            if (auto nodeInstance = Red::Cast<Red::worldINodeInstance>(object))
            {
                result.nodeInstance = nodeInstance;
                result.nodeDefinition = Raw::WorldNodeInstance::Node::Ref(nodeInstance);
                result.hash = reinterpret_cast<uint64_t>(nodeInstance.instance);
                result.resolved = true;
            }
            else if (auto& entity = Red::Cast<Red::entEntity>(object))
            {
                result.entity = entity;
                result.hash = reinterpret_cast<uint64_t>(entity.instance);
                result.resolved = true;

                if (entity->entityID.IsStatic())
                {
                    nodeInstance = m_nodeRegistry->FindStreamedNodeInstance(entity->entityID.hash);
                    if (nodeInstance)
                    {
                        result.nodeInstance = nodeInstance;
                        result.nodeDefinition = Raw::WorldNodeInstance::Node::Ref(nodeInstance);
                        // result.hash = reinterpret_cast<uint64_t>(nodeInstance.instance);
                    }
                }
            }
            else if (auto& component = Red::Cast<Red::entIComponent>(object))
            {
                result.component = component;
            }
            else if (!result.resolved)
            {
                result.hash = reinterpret_cast<uint64_t>(object.instance);
                result.resolved = true;
            }
        }
    }

    if (result.resolved)
    {
        result.proxyID = trace->proxyID;
        result.actorIndex = trace->actorIndex;
        result.actorOffset = 0;
        result.shapeIndex = trace->shapeIndex;
        result.distance = trace->distance;

        if (auto nodeInstance = Red::Cast<Red::worldCollisionNodeInstance>(result.nodeInstance.Lock()))
        {
            if (result.proxyID == Raw::WorldCollisionNodeInstance::SecondaryProxyID::Ref(nodeInstance))
            {
                auto& nodeDefinition = Raw::WorldCollisionNodeInstance::Node::Ref(nodeInstance);
                result.actorOffset = nodeDefinition->numActors / 2;
            }
        }
    }

    return result;
}

Red::Box App::WorldInspector::GetPhysicsProxyBoundingBox(uint32_t aProxyID, int32_t aActorIndex, int32_t aShapeIndex)
{
    Red::Box finalBox{{1,1,1,0}, {-1,-1,-1,0}};

    bool allActors = aActorIndex == -1;
    bool allShapes = allActors || aShapeIndex == -1;

    int32_t actorIndex = allActors ? 0 : aActorIndex;
    while (true)
    {
        Red::Transform actorTransform;
        Raw::PhysicsProxy::GetActorWorldTransform(actorTransform, aProxyID, actorIndex);

        if (actorTransform.position.X == 0 && actorTransform.position.Y == 0 && actorTransform.position.Z == 0)
            break;

        int32_t shapeIndex = allShapes ? 0 : aShapeIndex;
        while (true)
        {
            Red::PhysicsGeometryProxy shapeGeometry;
            Raw::PhysicsProxy::GetShapeGeometry(shapeGeometry, aProxyID, actorIndex, shapeIndex);

            if (shapeGeometry.type == Red::PhysicsGeometryType::Invalid)
            {
                Raw::PhysicsGeometry::Destruct(shapeGeometry);
                break;
            }

            Red::Transform shapeTransform;
            Raw::PhysicsProxy::GetShapeLocalTransform(shapeTransform, aProxyID, actorIndex, shapeIndex);

            Red::Box shapeBox;
            Raw::PhysicsGeometry::GetBoundingBox(shapeGeometry, shapeBox, shapeTransform);

            Raw::PhysicsGeometry::Destruct(shapeGeometry);

            if (Red::IsValidBox(shapeBox))
            {
                Red::CombineBox(finalBox, shapeBox);
            }

            if (!allShapes)
                break;

            ++shapeIndex;
        }

        if (!allActors)
            break;

        ++actorIndex;
    }

    return finalBox;
}

App::PhysicsTraceResulGeometry App::WorldInspector::GetPhysicsProxyGeometry(uint32_t aProxyID, int32_t aActorIndex, int32_t aShapeIndex)
{
    bool allActors = aActorIndex == -1;

    Red::Transform finalTransform;
    Raw::PhysicsProxy::GetActorWorldTransform(finalTransform, aProxyID, allActors ? 0 : aActorIndex);

    return {finalTransform.position, finalTransform.orientation, GetPhysicsProxyBoundingBox(aProxyID, aActorIndex, aShapeIndex)};
}

App::PhysicsTraceResulGeometry App::WorldInspector::GetPhysicsObjectGeometry(
    const Red::Handle<Red::ISerializable>& aObject, int32_t aActorIndex, int32_t aShapeIndex)
{
    if (auto entity = Red::Cast<Red::entEntity>(aObject))
    {
        if (entity->entityID.hash == 1)
            return {};

        Red::Box entityBox{};
        Red::Vector4 entityPosition = entity->transformComponent->worldTransform.Position;
        Red::Quaternion entityRotation = entity->transformComponent->worldTransform.Orientation;

        Red::Transform inverseTransform = {entityPosition, entityRotation};
        Red::CallStatic("Transform", "SetInverse", inverseTransform);

        for (const auto& component : entity->components)
        {
            const auto& placedComponent = Red::Cast<Red::entIPlacedComponent>(component);

            if (!placedComponent || !placedComponent->isEnabled)
                continue;
#ifndef NDEBUG
            auto _componentName = placedComponent->name.ToString();
            auto _componentType = placedComponent->GetType()->GetName().ToString();
#endif
            uint32_t componentProxyID = -1;
            Red::Vector3 componentScale = {1, 1, 1};

            if (const auto& collider = Red::Cast<Red::entColliderComponent>(placedComponent))
            {
                if (collider->filterData->preset == "NPC Hitbox" ||
                    collider->filterData->preset == "NPC Collision" ||
                    collider->filterData->preset == "Interaction Object")
                    continue;

                componentProxyID = *std::bit_cast<uint32_t*>(&collider->unk1A2[2]);
            }
            else if (const auto& simpleCollider = Red::Cast<Red::entSimpleColliderComponent>(placedComponent))
            {
                componentProxyID = *std::bit_cast<uint32_t*>(&simpleCollider->unk140);
            }
            else if (const auto& physicalMesh = Red::Cast<Red::entPhysicalMeshComponent>(placedComponent))
            {
                if (physicalMesh->LODMode == Red::entMeshComponentLODMode::AppearanceProxy ||
                    physicalMesh->unk234[1] == 1)
                    continue;

                componentProxyID = *std::bit_cast<uint32_t*>(&physicalMesh->unk228);
                componentScale = physicalMesh->visualScale;
            }
            else if (const auto& physicalSkinnedMesh = Red::Cast<Red::entPhysicalSkinnedMeshComponent>(placedComponent))
            {
                if (physicalSkinnedMesh->LODMode == Red::entMeshComponentLODMode::AppearanceProxy)
                    continue;

                componentProxyID = *std::bit_cast<uint32_t*>(&physicalSkinnedMesh->unk2B8[8]);
            }
            else if (const auto& physicalDestruction = Red::Cast<Red::entPhysicalDestructionComponent>(placedComponent))
            {
                componentProxyID = *std::bit_cast<uint32_t*>(&physicalDestruction->unk310);
            }
            else if (const auto& vehicleChassis = Red::Cast<Red::vehicleChassisComponent>(placedComponent))
            {
                componentProxyID = *std::bit_cast<uint32_t*>(&vehicleChassis->unk158[8]);
            }
            else if (const auto& corpse = Red::Cast<Red::entCorpseComponent>(placedComponent))
            {
                componentProxyID = *std::bit_cast<uint32_t*>(&corpse->unk178);
            }

            if (componentProxyID == -1)
                continue;

            auto componentGeometry = GetPhysicsProxyGeometry(componentProxyID, -1, -1);
            auto& componentBox = componentGeometry.boundingBox;

            if (Red::IsValidBox(componentBox))
            {
                Red::Transform componentTransform = {componentGeometry.position, componentGeometry.orientation};
                Red::CallGlobal("OperatorMultiply;TransformTransform;Transform", componentTransform, componentTransform, inverseTransform);

                Red::TransformBox(componentBox, componentTransform);
                Red::ScaleBox(componentBox, componentScale);
                Red::CombineBox(entityBox, componentBox);
            }
        }

        return {entityPosition, entityRotation, entityBox};
    }

    return {};
}

Red::Vector4 App::WorldInspector::ProjectWorldPoint(const Red::Vector4& aPoint)
{
    auto* camera = Raw::CameraSystem::Camera::Ptr(m_cameraSystem);
    auto& point = *reinterpret_cast<const Red::Vector3*>(&aPoint);

    Red::Vector4 result{};
    Raw::Camera::ProjectPoint(camera, result, point);

    return result;
}

Red::Vector4 App::WorldInspector::GetFrustumNearPlane()
{
    Red::Frustum cameraFrustum;
    Raw::CameraSystem::GetCameraFrustum(m_cameraSystem, cameraFrustum);

    return *std::bit_cast<Red::Vector4*>(&cameraFrustum.planes[0]);
}

void App::WorldInspector::OnCollectNodeParallel(uint64_t a1, uint64_t a2, Red::Vector3* aPosition,
                                                uint64_t a4, uint32_t a5)
{
    if (s_streamingOverride)
    {
        *aPosition = s_streamingOverridePosition.AsVector3();
    }
}

void App::WorldInspector::SetStreamingOverrideState(bool aState)
{
    s_streamingOverride = aState;
}

bool App::WorldInspector::GetStreamingOverrideState()
{
    return s_streamingOverride;
}

void App::WorldInspector::SetStreamingOverridePosition(const Red::Vector4& aPosition)
{
    s_streamingOverridePosition = aPosition;
}

Red::Vector4 App::WorldInspector::GetStreamingOverridePosition()
{
    return s_streamingOverridePosition;
}
