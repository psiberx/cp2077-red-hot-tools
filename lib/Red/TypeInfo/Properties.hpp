#pragma once

#include "Common.hpp"
#include "Resolving.hpp"

namespace Red
{
template<typename T>
inline T* GetPropertyPtr(ISerializable* aContext, CName aProp)
{
    if (!aContext)
        return nullptr;

    auto prop = aContext->GetType()->GetProperty(aProp);
    if (!prop)
        return nullptr;

    return prop->GetValuePtr<T>(aContext);
}

template<typename T>
inline T* GetPropertyPtr(void* aContext, CName aType, CName aProp)
{
    if (!aContext)
        return nullptr;

    auto type = GetClass(aType);
    if (!type)
        return nullptr;

    auto prop = type->GetProperty(aProp);
    if (!prop)
        return nullptr;

    return prop->GetValuePtr<T>(aContext);
}

template<typename T>
inline T* GetPropertyPtr(void* aContext, CClass* aType, CName aProp)
{
    if (!aContext || !aType)
        return nullptr;

    auto prop = aType->GetProperty(aProp);
    if (!prop)
        return nullptr;

    return prop->GetValuePtr<T>(aContext);
}

template<typename T>
inline T& GetProperty(ISerializable* aContext, CName aProp)
{
    return *GetPropertyPtr<T>(aContext, aProp);
}

template<typename T>
inline T& GetProperty(void* aContext, CName aType, CName aProp)
{
    return *GetPropertyPtr<T>(aContext, aType, aProp);
}

template<typename T>
inline T& GetProperty(void* aContext, CClass* aType, CName aProp)
{
    return *GetPropertyPtr<T>(aContext, aType, aProp);
}
}
