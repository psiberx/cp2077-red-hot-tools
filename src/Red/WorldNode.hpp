#pragma once

#include "Red/Rendering.hpp"

namespace Red
{
#pragma pack(push, 4)
struct WorldNodeRegistryEntry
{
    uint64_t id;
    WeakHandle<worldINodeInstance> node;
    uint32_t next;
};
#pragma pack(pop)
}

namespace Raw::WorldNode
{
constexpr auto GetBoundingBox = Core::RawVFunc<
    /* addr = */ 0x108,
    /* type = */ void (Red::worldNode::*)(Red::Box& aBox)>();

constexpr auto GetDynamicBoundingBox = Core::RawVFunc<
    /* addr = */ 0x110,
    /* type = */ void (Red::worldNode::*)(Red::Box& aBox)>();
}

namespace Raw::WorldInstancedMeshNode
{
using Bounds = Core::OffsetPtr<0x50, Red::DynArray<Red::Box>>;
}

namespace Raw::WorldNodeInstance
{
using Transform = Core::OffsetPtr<0x30, Red::Transform>;
using Scale = Core::OffsetPtr<0x50, Red::Vector3>;
using Node = Core::OffsetPtr<0x60, Red::Handle<Red::worldNode>>;
using Flags = Core::OffsetPtr<0x89, uint8_t>;

inline bool IsVisible(Red::worldINodeInstance* aNodeInstance)
{
    return Flags::Ref(aNodeInstance) & 2;
}

constexpr auto Initialize = Core::RawFunc<
    /* addr = */ 0x1401B96A4 - Red::Addresses::ImageBase, // FIXME
    /* type = */ bool (*)(Red::worldINodeInstance*, Red::CompiledNodeInstanceSetupInfo*, void*)>();

constexpr auto SetVisibility = Core::RawFunc<
    /* addr = */ 0x140783E28 - Red::Addresses::ImageBase, // FIXME
    /* type = */ void (*)(Red::worldINodeInstance*, bool aVisible)>();

constexpr auto UpdateVisibility = Core::RawVFunc<
    /* addr = */ 0xF8,
    /* type = */ void (Red::worldINodeInstance::*)(bool aVisible)>();
}

namespace Raw::WorldMeshNodeInstance
{
using Mesh = Core::OffsetPtr<0x98, Red::Handle<Red::CMesh>>;
using RenderProxy = Core::OffsetPtr<0xC8, Red::SharedPtr<Red::RenderProxy>>;
}

namespace Raw::WorldBendedMeshNodeInstance
{
using Mesh = Core::OffsetPtr<0xA0, Red::Handle<Red::CMesh>>;
using RenderProxy = Core::OffsetPtr<0xE0, Red::SharedPtr<Red::RenderProxy>>;
}

namespace Raw::WorldStaticDecalNodeInstance
{
using Material = Core::OffsetPtr<0xA0, Red::Handle<Red::IMaterial>>;
using RenderProxy = Core::OffsetPtr<0xB0, Red::SharedPtr<Red::RenderProxy>>;
}

namespace Raw::WorldPhysicalDestructionNodeInstance
{
using RenderProxy = Core::OffsetPtr<0x1D8, Red::SharedPtr<Red::RenderProxy>>;
}

namespace Raw::WorldInstancedDestructibleMeshNodeInstance
{
// using Mesh = Core::OffsetPtr<0x170, Red::Handle<Red::CMesh>>;
// using RenderProxy = Core::OffsetPtr<0x190, Red::SharedPtr<Red::RenderProxy>>;
}

namespace Raw::WorldInstancedMeshNodeInstance
{
using RenderProxies = Core::OffsetPtr<0xE8, Red::DynArray<Red::SharedPtr<Red::RenderProxy>>>;
}

namespace Raw::WorldTerrainMeshNodeInstance
{
using RenderProxies = Core::OffsetPtr<0xC0, Red::DynArray<Red::SharedPtr<Red::RenderProxy>>>;
}

namespace Raw::WorldFoliageNodeInstance
{
using Mesh = Core::OffsetPtr<0xB8, Red::Handle<Red::CMesh>>;
using RenderProxies = Core::OffsetPtr<0xF8, Red::DynArray<Red::SharedPtr<Red::RenderProxy>>>;
}

namespace Raw::WorldEntityNodeInstance
{
using Entity = Core::OffsetPtr<0xA0, Red::Handle<Red::Entity>>;
}

namespace Raw::WorldNodeRegistry
{
using EntriesLock = Core::OffsetPtr<0x48, Red::SharedMutex>;
using Entries = Core::OffsetPtr<0x50, Red::WorldNodeRegistryEntry*>;
using EntriesCount = Core::OffsetPtr<0x58, uint32_t>;

constexpr auto FindNode = Core::RawVFunc<
    /* addr = */ 0x190,
    /* type = */ void (Red::worldNodeInstanceRegistry::*)(Red::Handle<Red::worldINodeInstance>& aOut,
                                                          uint64_t aNodeID)>();
}
