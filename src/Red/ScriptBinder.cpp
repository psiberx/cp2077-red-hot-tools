#include "ScriptBinder.hpp"

Red::ScriptBinder::ScriptBinder(CRTTISystem* aRtti, const FileResolver& aFileResolver)
    : rtti(aRtti)
    , fileResolver(aFileResolver)
{
}

// bool Red::ScriptBinder::Bind(ScriptBundle& aData, ScriptReport& aReport)
// {
//     using func_t = bool (*)(ScriptBinder*, ScriptBundle&, ScriptReport&, bool);
//     static UniversalRelocFunc<func_t> func(AddressLib::ScriptBinder_Bind);
//     return func(this, aData, aReport, false);
// }

bool Red::ScriptBinder::ResolveNatives(DynArray<ScriptDefinition*>& aDefinitions, ScriptReport& aReport)
{
    using func_t = bool (*)(ScriptBinder*, DynArray<ScriptDefinition*>&, ScriptReport&);
    static UniversalRelocFunc<func_t> func(AddressLib::ScriptBinder_ResolveNatives);
    return func(this, aDefinitions, aReport);
}

void Red::ScriptBinder::ResolveTypes(DynArray<ScriptDefinition*>& aDefinitions)
{
    using func_t = void (*)(ScriptBinder*, DynArray<ScriptDefinition*>&);
    static UniversalRelocFunc<func_t> func(AddressLib::ScriptBinder_ResolveTypes);
    func(this, aDefinitions);
}

bool Red::ScriptBinder::CreateClass(ScriptClass* aClass, ScriptReport& aReport)
{
    using func_t = bool (*)(ScriptBinder*, ScriptClass*, ScriptReport&);
    static UniversalRelocFunc<func_t> func(AddressLib::ScriptBinder_CreateClass);
    return func(this, aClass, aReport);
}

bool Red::ScriptBinder::CreateEnum(ScriptEnum* aEnum, ScriptReport& aReport)
{
    using func_t = bool (*)(ScriptBinder*, ScriptEnum*, ScriptReport&);
    static UniversalRelocFunc<func_t> func(AddressLib::ScriptBinder_CreateEnum);
    return func(this, aEnum, aReport);
}

bool Red::ScriptBinder::CreateBitfield(ScriptBitfield* aBitfield, ScriptReport& aReport)
{
    using func_t = bool (*)(ScriptBinder*, ScriptBitfield*, ScriptReport&);
    static UniversalRelocFunc<func_t> func(AddressLib::ScriptBinder_CreateBitfield);
    return func(this, aBitfield, aReport);
}

bool Red::ScriptBinder::CreateProperties(ScriptClass* aClass, ScriptReport& aReport)
{
    using func_t = bool (*)(ScriptBinder*, ScriptClass*, ScriptReport&);
    static UniversalRelocFunc<func_t> func(AddressLib::ScriptBinder_CreateProperties);
    return func(this, aClass, aReport);
}

bool Red::ScriptBinder::CreateFunction(ScriptFunction* aFunc, ScriptReport& aReport)
{
    using func_t = bool (*)(ScriptBinder*, ScriptFunction*, ScriptReport&);
    static UniversalRelocFunc<func_t> func(AddressLib::ScriptBinder_CreateFunction);
    return func(this, aFunc, aReport);
}

void Red::ScriptBinder::TranslateBytecode(DynArray<ScriptDefinition*>& aDefinitions)
{
    using func_t = void (*)(ScriptBinder*, DynArray<ScriptDefinition*>&);
    static UniversalRelocFunc<func_t> func(AddressLib::ScriptBinder_TranslateBytecode);
    func(this, aDefinitions);
}
