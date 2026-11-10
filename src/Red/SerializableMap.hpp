#pragma once

namespace Red
{
struct SerializableMap;
}

namespace Raw::SerializableMap
{
constexpr auto Instance = Core::RawPtr<
    /* addr = */ Red::AddressLib::SerializableMap_Instance,
    /* type = */ Red::SerializableMap*>{};

constexpr auto CollectSerializables = Core::RawFunc<
    /* addr = */ Red::AddressLib::SerializableMap_CollectSerializables,
    /* type = */ uint32_t (*)(Red::SerializableMap* aMap,
                              Red::DynArray<Red::WeakHandle<Red::ISerializable>>& aOut)>{};
}

namespace Red
{
struct SerializableMap
{
    inline static SerializableMap* Get()
    {
        return Raw::SerializableMap::Instance;
    }

    inline void CollectSerializables(DynArray<WeakHandle<ISerializable>>& aOut)
    {
        Raw::SerializableMap::CollectSerializables(this, aOut);
    }
};
}
