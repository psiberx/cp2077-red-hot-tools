#include "InspectionSystem.hpp"
#include "Core/Facades/Container.hpp"
#include "Red/CameraSystem.hpp"
#include "Red/Debug.hpp"
#include "Red/Entity.hpp"
#include "Red/NodeRef.hpp"
#include "Red/Physics.hpp"
#include "Red/Rendering.hpp"
#include "Red/Transform.hpp"
#include "Red/WorldNode.hpp"

void App::InspectionSystem::OnWorldAttached(Red::world::RuntimeScene*)
{
    m_resourceRegistry = Core::Resolve<ResourceRegistry>();
    m_nodeRegistry = Red::GetRuntimeSystem<Red::worldNodeInstanceRegistry>();
    m_cameraSystem = Red::GetGameSystem<Red::gameICameraSystem>();
}

void App::InspectionSystem::OnAfterWorldDetach()
{
    m_resourceRegistry->ClearRuntimeData();
}

Red::CString App::InspectionSystem::ResolveResourcePath(uint64_t aResourceHash)
{
    return m_resourceRegistry->ResolveResorcePath(aResourceHash);
}

App::WorldNodeStaticData App::InspectionSystem::ResolveSectorDataFromNodeID(uint64_t aNodeID)
{
    {
        static const Red::GlobalNodeRef context{Red::FNV1a64("$")};

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
        static const Red::GlobalNodeRef context{Red::FNV1a64("$")};

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
    constexpr uint64_t prime = 0x100000001b3;
    constexpr uint64_t seed = 0xCBF29CE484222325;

    uint64_t hash = seed;
    const char* aText = aNodeRef.c_str();

    while (aText && *aText)
    {
        if (*aText == '#')
        {
            ++aText;
            continue;
        }

        if (*aText == ';')
        {
            ++aText;

            while (*aText && *aText != '/')
                ++aText;

            if (!*aText)
                break;
        }

        hash ^= *aText;
        hash *= prime;

        ++aText;
    }

    return hash == seed ? 0 : hash;
}

Red::EntityID App::InspectionSystem::ResolveCommunityIDFromEntityID(uint64_t aEntityID)
{
    auto entityStubSystem = Red::GetGameSystem<Red::IEntityStubSystem>();
    auto entityStub = entityStubSystem->FindStub(aEntityID);

    if (!entityStub)
        return {};

    return entityStub->stubState->spawnerId.entityId;
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

App::PhysicsTraceObject App::InspectionSystem::GetPhysicsTraceObject(Red::ScriptRef<Red::physicsTraceResult>& aTrace)
{
    PhysicsTraceObject result{};

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

App::WorldNodeSceneData App::InspectionSystem::FindStreamedWorldNode(uint64_t aNodeID)
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

Red::DynArray<App::WorldNodeSceneData> App::InspectionSystem::GetStreamedWorldNodesInFrustum()
{
    Red::Frustum cameraFrustum;
    Raw::CameraSystem::GetCameraFrustum(m_cameraSystem, cameraFrustum);

    Red::DynArray<WorldNodeSceneData> frustumNodes;

    const Red::Box dummyBox{{-0.1, -0.1, -0.1, 1.0}, {0.1, 0.1, 0.1, 1.0}};

    for (const auto& [setup, nodeInstanceWeak, nodeDefinitionWeak] : m_resourceRegistry->GetAllStreamedNodes())
    {
        auto nodeInstance = nodeInstanceWeak.Lock();
        auto nodeDefinition = nodeDefinitionWeak.Lock();

        if (!nodeInstance || !nodeDefinition)
            continue;

        auto& transform = Raw::WorldNodeInstance::Transform::Ref(nodeInstance);
        auto& scale = Raw::WorldNodeInstance::Scale::Ref(nodeInstance);

        if (Red::IsInstanceOf<Red::worldMeshNode>(nodeDefinition))
        {
            auto& mesh = Raw::WorldMeshNodeInstance::Mesh::Ref(nodeInstance);
            if (mesh)
            {
                auto worldBox = mesh->boundingBox;
                Red::ScaleBox(worldBox, scale);
                Red::TransformBox(worldBox, transform);

                if (cameraFrustum.Test(worldBox) != Red::FrustumResult::Outside)
                {
                    frustumNodes.PushBack({nodeInstanceWeak, nodeDefinitionWeak, transform, worldBox});
                }
                continue;
            }
        }
        else if (Red::IsInstanceOf<Red::worldInstancedMeshNode>(nodeDefinition))
        {
            for (const auto& worldBox : Raw::WorldInstancedMeshNode::Bounds::Ref(nodeDefinition))
            {
                if (cameraFrustum.Test(worldBox) != Red::FrustumResult::Outside)
                {
                    frustumNodes.PushBack({nodeInstanceWeak, nodeDefinitionWeak, transform, worldBox});
                }
            }
            continue;
        }
        else if (Red::IsInstanceOf<Red::worldAreaShapeNode>(nodeDefinition) ||
                 Red::IsInstanceOf<Red::worldBendedMeshNode>(nodeDefinition))
        {
            Red::Box worldBox{};
            Raw::WorldNode::GetBoundingBox(nodeDefinition, worldBox);

            if (Red::IsValidBox(worldBox))
            {
                Red::ScaleBox(worldBox, scale);
                Red::TransformBox(worldBox, transform);

                if (cameraFrustum.Test(worldBox) != Red::FrustumResult::Outside)
                {
                    frustumNodes.PushBack({nodeInstanceWeak, nodeDefinitionWeak, transform, worldBox});
                }
                continue;
            }
        }

        auto worldBox = dummyBox;
        Red::TransformBox(worldBox, transform);

        if (cameraFrustum.Test(worldBox) == Red::FrustumResult::Inside)
        {
            frustumNodes.PushBack({nodeInstanceWeak, nodeDefinitionWeak, transform, {}});
        }
    }

    return frustumNodes;
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

Red::Vector4 App::InspectionSystem::ProjectWorldPoint(const Red::Vector4& aPoint)
{
    auto* camera = Raw::CameraSystem::Camera::Ptr(m_cameraSystem);
    auto& point = *reinterpret_cast<const Red::Vector3*>(&aPoint);

    Red::Vector4 result{};
    Raw::Camera::ProjectPoint(camera, result, point);

    if (result.W > 0)
    {
        *reinterpret_cast<__m128*>(&result) = _mm_div_ps(*reinterpret_cast<__m128*>(&result), _mm_set1_ps(result.W));
    }

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
