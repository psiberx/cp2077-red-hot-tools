#include "ScriptBundle.hpp"
#include "Red/FileSystem.hpp"

Red::ScriptBundle::ScriptBundle()
{
    using func_t = void (*)(ScriptBundle*);
    static UniversalRelocFunc<func_t> func(AddressLib::ScriptBundle_ctor);
    func(this);
}

Red::ScriptBundle::~ScriptBundle()
{
    using func_t = void (*)(ScriptBundle*);
    static UniversalRelocFunc<func_t> func(AddressLib::ScriptBundle_dtor);
    func(this);
}

bool Red::ScriptBundle::Read(const CString& aPath)
{
    auto file = FileSystem::Get()->Open(aPath, 1);
    if (file)
    {
        using func_t = bool (*)(ScriptBundle*, uint64_t);
        static UniversalRelocFunc<func_t> func(AddressLib::ScriptBundle_Read);
        return func(this, file.ptr);
    }
    else
    {
        return false;
    }
}

Red::DynArray<Red::ScriptDefinition*> Red::ScriptBundle::Collect(bool aDeep) const
{
    using func_t = bool (*)(const ScriptBundle*, DynArray<ScriptDefinition*>&, bool);
    static UniversalRelocFunc<func_t> func(AddressLib::ScriptBundle_Collect);

    DynArray<ScriptDefinition*> definitions;
    func(this, definitions, aDeep);

    return definitions;
}
