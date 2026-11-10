#include "ObjectRegistry.hpp"
#include "Red/SerializableMap.hpp"

namespace
{
Red::ClassLocator<Red::IScriptable> s_IScriptableType;
}

void App::ObjectRegistry::CollectSerializables(Red::DynArray<Red::WeakHandle<Red::ISerializable>>& aOut)
{
    Red::SerializableMap::Get()->CollectSerializables(aOut);
}

void App::ObjectRegistry::CollectScriptables(Red::DynArray<Red::WeakHandle<Red::IScriptable>>& aOut)
{
    Red::DynArray<Red::WeakHandle<Red::ISerializable>> serializables;
    Red::SerializableMap::Get()->CollectSerializables(serializables);

    for (const auto& weak : serializables)
    {
        if (!weak.Expired() && weak.instance->GetType()->IsA(s_IScriptableType))
        {
            aOut.EmplaceBack(*reinterpret_cast<const Red::WeakHandle<Red::IScriptable>*>(&weak));
        }
    }
}

void App::ObjectRegistry::CreateSnapshot()
{
    std::unique_lock lock(s_snapshotLock);

    s_snapshot.clear();

    Red::DynArray<Red::WeakHandle<Red::ISerializable>> serializables;
    Red::SerializableMap::Get()->CollectSerializables(serializables);

    for (const auto& weak : serializables)
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
    std::unique_lock lock2(s_snapshotLock);

    Red::DynArray<Red::WeakHandle<Red::ISerializable>> serializables;
    Red::SerializableMap::Get()->CollectSerializables(serializables);

    for (const auto& weak : serializables)
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
