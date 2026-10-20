#include "ObjectRegistry.hpp"
#include "Red/ISerializable.hpp"

namespace
{
Red::ClassLocator<Red::IScriptable> s_IScriptableType;
}

void App::ObjectRegistry::OnBootstrap()
{
    s_registry.reserve(StartCapacity);
    LogInfo("[ObjectRegistry] Storage initialized for {} handles.", s_registry.capacity());

    Hook<Raw::ISerializable::CreateHandle>(&OnCreateHandle);
}

void* App::ObjectRegistry::OnCreateHandle(Red::Handle<Red::ISerializable>& aHandle, Red::ISerializable* aObject)
{
    auto isNewHandle = aObject && !aObject->ref.refCount;

    Raw::ISerializable::CreateHandle(aHandle, aObject);

    if (isNewHandle)
    {
        std::unique_lock lock(s_registryLock);

        if (s_registry.size() == s_registry.capacity())
        {
            auto [b, e] = std::ranges::remove_if(s_registry, [](auto& x) { return x.Expired(); });

            if (b != e)
            {
                s_registry.erase(b, e);
            }
            else
            {
                if (s_registry.capacity() == MaxCapacity)
                {
                    LogWarning("[ObjectRegistry] Storage reached max capacity of {} handles.", s_registry.capacity());
                    return &aHandle;
                }

                s_registry.reserve(s_registry.capacity() + s_registry.capacity() / 4);

                LogInfo("[ObjectRegistry] Storage capacity increased to {} handles.", s_registry.capacity());
            }
        }

        s_registry.emplace_back(aHandle);
    }

    return &aHandle;
}

void App::ObjectRegistry::CollectSerializables(Red::DynArray<Red::WeakHandle<Red::ISerializable>>& aOut)
{
    std::shared_lock lock(s_registryLock);

    for (const auto& weak : s_registry)
    {
        if (!weak.Expired())
        {
            aOut.EmplaceBack(weak);
        }
    }
}

void App::ObjectRegistry::CollectScriptables(Red::DynArray<Red::WeakHandle<Red::IScriptable>>& aOut)
{
    std::shared_lock lock(s_registryLock);

    for (const auto& weak : s_registry)
    {
        if (!weak.Expired() && weak.instance->GetType()->IsA(s_IScriptableType))
        {
            aOut.EmplaceBack(*reinterpret_cast<const Red::WeakHandle<Red::IScriptable>*>(&weak));
        }
    }
}

void App::ObjectRegistry::CreateSnapshot()
{
    std::shared_lock lock1(s_registryLock);
    std::unique_lock lock2(s_snapshotLock);

    s_snapshot.clear();

    for (const auto& weak : s_registry)
    {
        if (weak.Expired())
            continue;

        if (!weak.instance->GetType()->IsA(s_IScriptableType))
            continue;

        auto cls = weak.instance->GetType();

        if (!cls->holderSize)
            continue;

        auto it = s_snapshot.find(cls->GetName());

        if (it != s_snapshot.end())
            continue;

        auto& desc = s_snapshot.insert({cls->name, {}}).first.value();

        Red::DynArray<Red::CProperty*> props;
        cls->GetProperties(props);

        for (const auto& prop : props)
        {
            if (prop->flags.inValueHolder)
            {
                desc.props.emplace_back(prop->name, prop->type, prop->valueOffset);
            }
        }
    }
}

void App::ObjectRegistry::RestoreSnapshot()
{
    std::shared_lock lock1(s_registryLock);
    std::unique_lock lock2(s_snapshotLock);

    for (const auto& weak : s_registry)
    {
        if (weak.Expired())
            continue;

        if (!weak.instance->GetType()->IsA(s_IScriptableType))
            continue;

        auto instance = reinterpret_cast<Red::IScriptable*>(weak.instance);
        auto oldHolder = instance->valueHolder;

        if (!oldHolder)
            continue;

        auto cls = instance->GetType();
        auto it = s_snapshot.find(cls->GetName());

        if (it == s_snapshot.end())
            continue;

        instance->valueHolder = nullptr;
        auto newHolder = instance->GetValueHolder();

        for (auto& oldProp : it.value().props)
        {
            auto newProp = cls->GetProperty(oldProp.name);

            if (newProp && newProp->flags.inValueHolder && newProp->type == oldProp.type)
            {
                newProp->type->Assign(GetValuePtr(newHolder, newProp->valueOffset),
                                      GetValuePtr(oldHolder, oldProp.valueOffset));
            }

            oldProp.type->Destruct(GetValuePtr(oldHolder, oldProp.valueOffset));
        }
    }

    s_snapshot.clear();
}
