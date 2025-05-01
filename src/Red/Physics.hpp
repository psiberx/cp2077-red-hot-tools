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
    PhysicsGeometryType type; // 00
    uint8_t data[0x2C]{};     // 04 physx::PxGeometryHolder
};
RED4EXT_ASSERT_SIZE(PhysicsGeometryProxy, 0x30);
}

namespace Raw::PhysicsProxy
{
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
