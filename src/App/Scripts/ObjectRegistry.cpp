#include "ObjectRegistry.hpp"
#include "Red/ISerializable.hpp"
#include "Red/Rtti/Locator.hpp"

namespace
{
constexpr auto MaxNumObjects = 0x300000;

Red::Rtti::TypeLocator<"IScriptable"> s_IScriptableType;
}

void App::ObjectRegistry::OnBootstrap()
{
    s_objects.reserve(MaxNumObjects);

    HookAfter<Raw::ISerializable::SetReference>(+[](Red::ISerializable& aObject, Red::Handle<Red::ISerializable>&) {
        std::unique_lock lock(s_registryLock);

        s_objects.push_back(aObject.ref);

        if (s_objects.size() >= MaxNumObjects - 1)
        {
            Shrink();
        }
    });
}

void App::ObjectRegistry::CollectSerializables(Red::DynArray<Red::WeakHandle<Red::ISerializable>>& aOut)
{
    std::shared_lock lock(s_registryLock);

    for (const auto& weak : s_objects)
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

    for (const auto& weak : s_objects)
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

    for (const auto& weak : s_objects)
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
    std::unique_lock lock1(s_registryLock);
    std::unique_lock lock2(s_snapshotLock);

    for (auto& weak : s_objects)
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

    Shrink();
}

void App::ObjectRegistry::Shrink()
{
    auto [b, e] = std::ranges::remove_if(s_objects, [](auto& x) { return x.Expired(); });
    s_objects.erase(b, e);
}
