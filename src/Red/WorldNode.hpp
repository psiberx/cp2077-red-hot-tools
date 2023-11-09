#pragma once

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

namespace Raw::WorldNodeInstance
{
using Transform = Core::OffsetPtr<0x30, Red::Transform>;
using Scale = Core::OffsetPtr<0x50, Red::Vector3>;
using Node = Core::OffsetPtr<0x60, Red::Handle<Red::worldNode>>;
}

namespace Raw::WorldNodeRegistry
{
using EntriesLock = Core::OffsetPtr<0x48, Red::SharedMutex>;
using Entries = Core::OffsetPtr<0x50, Red::WorldNodeRegistryEntry*>;
using EntriesCount = Core::OffsetPtr<0x58, uint32_t>;

constexpr auto FindNode = Core::RawVFunc<
    /* addr = */ 0x190,
    /* type = */ void (Red::worldNodeInstanceRegistry::*)(Red::Handle<Red::worldINodeInstance>& aOut, uint64_t aNodeID)>();
}
