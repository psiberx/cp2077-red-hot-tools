#include "InspectionSystem.hpp"
#include "Core/Facades/Container.hpp"
#include "Red/Debug.hpp"
#include "Red/Entity.hpp"
#include "Red/NodeRef.hpp"
#include "Red/Physics.hpp"
#include "Red/WorldNode.hpp"

void App::InspectionSystem::OnWorldAttached(Red::world::RuntimeScene*)
{
    m_registry = Core::Resolve<ResourceRegistry>();
}

void App::InspectionSystem::OnAfterWorldDetach()
{
    m_registry->ClearRuntimeData();
}

Red::CString App::InspectionSystem::ResolveResourcePath(uint64_t aResourceHash)
{
    return m_registry->ResolveResorcePath(aResourceHash);
}

App::StreamingSectorLocation App::InspectionSystem::ResolveSectorFromNodeHash(uint64_t aNodeID)
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

    return m_registry->ResolveSectorLocation(aNodeID);
}

App::StreamingSectorLocation App::InspectionSystem::ResolveSectorFromNode(
    const Red::WeakHandle<Red::ISerializable>& aNode)
{
    return m_registry->ResolveSectorLocation(aNode.instance);
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

uint64_t App::InspectionSystem::ResolveNodeRefHash(const Red::CString& aNodeRef)
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

Red::EntityID App::InspectionSystem::ResolveCommunityIDFromEntityID(Red::EntityID aEntityID)
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
            auto objectType = object->GetType();

            if (objectType->IsA(Red::GetType<Red::worldINodeInstance>()))
            {
                object = Raw::WorldNodeInstance::Node::Ref(object);
                objectType = object->GetType();
            }

            result.object = object;
            result.type = objectType->GetName();
            result.hash = reinterpret_cast<uint64_t>(object.instance);
            result.scriptable = objectType->IsA(Red::GetType<IScriptable>());
            result.resolved = true;
            break;
        }
    }

    return result;
}

bool App::PhysicsObjectResult::IsA(Red::CName aType)
{
    return resolved && object.instance->GetType()->IsA(Red::GetType(aType));
}
