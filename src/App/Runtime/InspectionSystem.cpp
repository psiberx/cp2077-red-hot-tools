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

Red::DynArray<Red::Handle<Red::IComponent>> App::InspectionSystem::GetComponents(
    const Red::WeakHandle<Red::Entity>& aEntity)
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
            Raw::WorldNodeRegistry::FindNode(m_nodeRegistry, nodeInstance, entityID.hash);

            if (nodeInstance)
            {
                result.node = Raw::WorldNodeInstance::Node::Ref(nodeInstance);
            }
        }
    }

    return result;
}

Red::WeakHandle<Red::worldNode> App::InspectionSystem::FindStreamedWorldNode(uint64_t aNodeID)
{
    Red::Handle<Red::worldINodeInstance> nodeInstance;
    Raw::WorldNodeRegistry::FindNode(m_nodeRegistry, nodeInstance, aNodeID);

    if (!nodeInstance)
        return {};

    return Raw::WorldNodeInstance::Node::Ref(nodeInstance);
}

Red::DynArray<App::WorldNodeSceneData> App::InspectionSystem::GetWorldNodesInFrustum()
{
    static const auto s_meshNodeType = Red::GetClass("worldMeshNode");
    static const auto s_decalNodeType = Red::GetClass("worldStaticDecalNode");
    static const auto s_entityNodeType = Red::GetClass("worldEntityNode");
    static const auto s_areaNodeType = Red::GetClass("worldAreaShapeNode");

    Red::Frustum cameraFrustum;
    Raw::CameraSystem::GetCameraFrustum(m_cameraSystem, cameraFrustum);

    Red::DynArray<WorldNodeSceneData> frustumNodes;

    for (const auto& [node, setup] : m_resourceRegistry->GetStreamedNodes())
    {
        if (!node)
            continue;

        if (!node.instance->GetType()->IsA(s_meshNodeType) && !node.instance->GetType()->IsA(s_decalNodeType) &&
            !node.instance->GetType()->IsA(s_entityNodeType) && !node.instance->GetType()->IsA(s_areaNodeType))
            continue;

        Red::Box nodeBox{};
        Raw::WorldNode::GetBoundingBox(node.instance, nodeBox);

        // {
        //     Red::Box modBox{};
        //     Raw::WorldNode::GetDynamicBoundingBox(node.instance, modBox);
        //
        //     if (modBox.Max.X >= modBox.Min.X && modBox.Max.Y >= modBox.Min.Y && modBox.Max.Z >= modBox.Min.Z)
        //     {
        //         *reinterpret_cast<__m128*>(&nodeBox.Min) = _mm_min_ps(*reinterpret_cast<__m128*>(&nodeBox.Min),
        //         *reinterpret_cast<__m128*>(&modBox.Min)); *reinterpret_cast<__m128*>(&nodeBox.Max) =
        //         _mm_max_ps(*reinterpret_cast<__m128*>(&nodeBox.Max), *reinterpret_cast<__m128*>(&modBox.Max));
        //     }
        // }

        if (nodeBox.Max.X < nodeBox.Min.X || nodeBox.Max.Y < nodeBox.Min.Y || nodeBox.Max.Z < nodeBox.Min.Z)
        {
            continue;
        }

        Red::Vector4 scale{setup->scale.X, setup->scale.Y, setup->scale.Z, 1.0};
        *reinterpret_cast<__m128*>(&nodeBox.Min) =
            _mm_mul_ps(*reinterpret_cast<__m128*>(&nodeBox.Min), *reinterpret_cast<__m128*>(&scale));
        *reinterpret_cast<__m128*>(&nodeBox.Max) =
            _mm_mul_ps(*reinterpret_cast<__m128*>(&nodeBox.Max), *reinterpret_cast<__m128*>(&scale));

        Red::Box worldBox{};
        Raw::Transform::ApplyToBox(setup->transform, worldBox, nodeBox);

        if (cameraFrustum.Test(worldBox) != Red::FrustumResult::Outside)
        {
            frustumNodes.PushBack({node, setup->transform, worldBox, reinterpret_cast<uint64_t>(node.instance)});
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
