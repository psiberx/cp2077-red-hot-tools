#include "InspectionSystem.hpp"
#include "Core/Facades/Container.hpp"
#include "Red/CameraSystem.hpp"
#include "Red/Debug.hpp"
#include "Red/Entity.hpp"
#include "Red/NodeRef.hpp"
#include "Red/Physics.hpp"
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
    // static const auto s_allowedNodeTypes = {
    //     Red::GetClass("worldMeshNode"),
    //     Red::GetClass("worldStaticDecalNode"),
    //     Red::GetClass("worldEntityNode"),
    //     Red::GetClass("worldAreaShapeNode"),
    //     Red::GetClass("worldBendedMeshNode"),
    //     Red::GetClass("worldCompiledCommunityAreaNode"),
    //     Red::GetClass("worldPopulationSpawnerNode"),
    // };

    Red::Frustum cameraFrustum;
    Raw::CameraSystem::GetCameraFrustum(m_cameraSystem, cameraFrustum);

    Red::DynArray<WorldNodeSceneData> frustumNodes;

    Red::Box nodeBox{};
    nodeBox.Min = {-0.1, -0.1, -0.1, 1.0};
    nodeBox.Max = {0.1, 0.1, 0.1, 1.0};

    for (const auto& [setup, nodeInstanceWeak, nodeDefinitionWeak] : m_resourceRegistry->GetAllStreamedNodes())
    {
        auto nodeInstance = nodeInstanceWeak.Lock();
        auto nodeDefinition = nodeDefinitionWeak.Lock();

        if (!nodeInstance || !nodeDefinition)
            continue;

        // if (std::ranges::all_of(s_allowedNodeTypes, [&nodeDefinition](const Red::CClass* aType) {
        //         return !nodeDefinition->GetType()->IsA(aType);
        //     }))
        //     continue;

        Red::Box worldBox{};
        Raw::Transform::ApplyToBox(setup->transform, worldBox, nodeBox);

        if (cameraFrustum.Test(worldBox) == Red::FrustumResult::Inside)
        {
            frustumNodes.PushBack({nodeInstanceWeak, nodeDefinitionWeak, setup->transform, worldBox});
        }
    }

    return frustumNodes;
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
