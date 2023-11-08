#include "InspectionSystem.hpp"
#include "Core/Facades/Container.hpp"
#include "Red/Debug.hpp"
#include "Red/Entity.hpp"
#include "Red/NodeRef.hpp"
#include "Red/Physics.hpp"
#include "Red/WorldNode.hpp"

void App::InspectionSystem::OnWorldAttached(Red::world::RuntimeScene*)
{
    m_resourceRegistry = Core::Resolve<ResourceRegistry>();
    m_worldNodeRegistry = Red::GetRuntimeSystem<Red::worldNodeInstanceRegistry>();
}

void App::InspectionSystem::OnAfterWorldDetach()
{
    m_resourceRegistry->ClearRuntimeData();
}

Red::CString App::InspectionSystem::ResolveResourcePath(uint64_t aResourceHash)
{
    return m_resourceRegistry->ResolveResorcePath(aResourceHash);
}

App::WorldNodeStaticData App::InspectionSystem::ResolveNodeDataFromNodeID(uint64_t aNodeID)
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

    return m_resourceRegistry->GetWorldNodeStaticData(aNodeID);
}

App::WorldNodeStaticData App::InspectionSystem::ResolveNodeDataFromNode(
    const Red::WeakHandle<Red::ISerializable>& aNode)
{
    return m_resourceRegistry->GetWorldNodeStaticData(aNode.instance);
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

Red::DynArray<Red::Handle<Red::IComponent>> App::InspectionSystem::GetComponents(const Red::WeakHandle<Red::Entity>& aEntity)
{
    if (aEntity.Expired())
        return {};

    return Raw::Entity::ComponentsStorage::Ptr(aEntity.instance)->components;
}

App::PhysicsObjectResult App::InspectionSystem::GetPhysicsTraceObject(Red::ScriptRef<Red::physicsTraceResult>& aTrace)
{
    PhysicsObjectResult result{};

    if (!aTrace)
        return result;

    auto& resultID = Raw::PhysicsTraceResult::ResultID::Ref(aTrace.ref);

    for (uint32_t i = 0; i < 2; ++i)
    {
        Red::Handle<Red::ISerializable> object;
        Raw::PhysicsTraceResult::GetHitObject(object, resultID, i);

        if (object)
        {
            if (object->GetType()->IsA(Red::GetType<Red::worldINodeInstance>()))
            {
                result.node = Raw::WorldNodeInstance::Node::Ref(object);
            }
            else
            {
                result.entity = Red::Cast<Red::entEntity>(object);
            }

            result.hash = reinterpret_cast<uint64_t>(object.instance);
            result.resolved = true;
            break;
        }
    }

    if (result.entity)
    {
        const auto& entityID = Raw::Entity::EntityID::Ref(result.entity.instance);
        if (entityID.IsStatic())
        {
            Red::Handle<Red::worldINodeInstance> nodeInstance;
            Raw::WorldNodeRegistry::FindNode(m_worldNodeRegistry, nodeInstance, entityID.hash);

            if (nodeInstance)
            {
                result.node = Raw::WorldNodeInstance::Node::Ref(nodeInstance);
            }
        }
    }

    return result;
}

Red::WeakHandle<Red::worldNode> App::InspectionSystem::FindWorldNode(uint64_t aNodeID)
{
    Red::Handle<Red::worldINodeInstance> nodeInstance;
    Raw::WorldNodeRegistry::FindNode(m_worldNodeRegistry, nodeInstance, aNodeID);

    if (!nodeInstance)
        return {};

    return Raw::WorldNodeInstance::Node::Ref(nodeInstance);
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
