#pragma once

namespace Red
{
enum class PhysicsGeometryType : int32_t
{
    Invalid = -1,
    Sphere,
    Plane,
    Capsule,
    Box,
    ConvexMesh,
    TriangleMesh,
    HeightField,
};

struct PhysicsGeometryProxy
{
    PhysicsGeometryType type{PhysicsGeometryType::Invalid}; // 00
    uint8_t data[0x2C]{};                                   // 04 physx::PxGeometryHolder
};
RED4EXT_ASSERT_SIZE(PhysicsGeometryProxy, 0x30);

struct PhysicsRaycastRequest
{
    Vector3 position;            // 00
    Vector3 direction;           // 0C
    float distance;              // 18
    physics::QueryFilter filter; // 20
    uint64_t unk28;              // 30
    uint8_t flags;               // 38
};
RED4EXT_ASSERT_SIZE(PhysicsRaycastRequest, 0x40);
RED4EXT_ASSERT_OFFSET(PhysicsRaycastRequest, position, 0x0);
RED4EXT_ASSERT_OFFSET(PhysicsRaycastRequest, direction, 0xC);
RED4EXT_ASSERT_OFFSET(PhysicsRaycastRequest, distance, 0x18);
RED4EXT_ASSERT_OFFSET(PhysicsRaycastRequest, filter, 0x20);

using PhysicsTraceResultArray = StaticArray<physics::TraceResult, 32>;
}

namespace Raw::PhysicsProxy
{
constexpr auto GetNumActors = Core::RawFunc<
    /* addr = */ Red::AddressLib::PhysicsProxy_GetNumActors,
    /* type = */ uint32_t (*)(uint32_t aProxyID)>();

constexpr auto GetActorPhysxPtr = Core::RawFunc<
    /* addr = */ Red::AddressLib::PhysicsProxy_GetActorPhysxPtr,
    /* type = */ void* (*)(uint32_t aProxyID, uint32_t aActorIndex)>();

constexpr auto GetActorWorldTransform = Core::RawFunc<
    /* addr = */ Red::AddressLib::PhysicsProxy_GetActorWorldTransform,
    /* type = */ void (*)(Red::Transform& aOut, uint32_t aProxyID, uint32_t aActorIndex)>();

constexpr auto GetShapeGeometry = Core::RawFunc<
    /* addr = */ Red::AddressLib::PhysicsProxy_GetShapeGeometry,
    /* type = */ void (*)(Red::PhysicsGeometryProxy& aOut, uint32_t aProxyID, uint32_t aActorIndex, uint32_t aShapeIndex)>();

constexpr auto GetShapeLocalTransform = Core::RawFunc<
    /* addr = */ Red::AddressLib::PhysicsProxy_GetShapeLocalTransform,
    /* type = */ void (*)(Red::Transform& aOut, uint32_t aProxyID, uint32_t aActorIndex, uint32_t aShapeIndex)>();

constexpr auto GetHitObject = Core::RawFunc<
    /* addr = */ Red::AddressLib::PhysicsProxy_GetHitObject,
    /* type = */ void* (*)(Red::Handle<Red::ISerializable>& aOut, uint32_t aProxyID, uint32_t aIndex)>();
}

namespace Raw::PhysicsGeometry
{
constexpr auto Destruct = Core::RawFunc<
    /* addr = */ Red::AddressLib::PhysicsGeometry_Destruct,
    /* type = */ void* (*)(const Red::PhysicsGeometryProxy& aGeometry)>();

constexpr auto GetBoundingBox = Core::RawFunc<
    /* addr = */ Red::AddressLib::PhysicsGeometry_GetBoundingBox,
    /* type = */ void* (*)(const Red::PhysicsGeometryProxy& aGeometry, Red::Box& aOut, const Red::Transform& aWorldTransform)>();

constexpr auto FixOrientation = Core::RawFunc<
    /* addr = */ Red::AddressLib::PhysicsGeometry_FixOrientation,
    /* type = */ void* (*)(const Red::PhysicsGeometryProxy& aGeometry, Red::Quaternion& aOrientation)>();
}

namespace Raw::PhysicsScene
{
constexpr auto SyncRaycastMultiple = Core::RawFunc<
    /* addr = */ Red::AddressLib::PhysicsScene_SyncRaycastMultiple,
    /* type = */ void (*)(uint32_t aSceneProxyID,
                          const Red::PhysicsRaycastRequest& aRequest,
                          Red::PhysicsTraceResultArray& aResults)>();
}

namespace Raw::RuntimeSystemPhysics
{
using SceneProxyID = Core::OffsetPtr<0x58, uint32_t>;
}
