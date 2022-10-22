#pragma once

#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "Core/Logging/LoggingAgent.hpp"

namespace App
{
class ObjectRegistry
    : public Core::Feature
    , public Core::LoggingAgent
    , public Core::HookingAgent
{
public:
    void CollectSerializables(Red::DynArray<Red::WeakHandle<Red::ISerializable>>& aOut);
    void CollectScriptables(Red::DynArray<Red::WeakHandle<Red::IScriptable>>& aOut);
    void CreateSnapshot();
    void RestoreSnapshot();

protected:
    void OnBootstrap() override;

    static void Shrink();

    template<typename T>
    inline static T* GetValuePtr(T* aPtr, uint32_t aOffset)
    {
        return reinterpret_cast<T*>(reinterpret_cast<uintptr_t>(aPtr) + aOffset);
    }

    struct PropDesc
    {
        Red::CName name;
        Red::CBaseRTTIType* type;
        uint32_t valueOffset;
    };

    struct ClassDesc
    {
        Core::Vector<PropDesc> props;
    };

    inline static std::shared_mutex s_registryLock;
    inline static Core::Vector<Red::WeakHandle<Red::ISerializable>> s_objects;

    inline static std::shared_mutex s_snapshotLock;
    inline static Core::Map<Red::CName, ClassDesc> s_snapshot;
};
}
