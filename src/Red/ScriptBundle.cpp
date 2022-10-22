#include "ScriptBundle.hpp"
#include "Addresses.hpp"

Red::ScriptBundle::ScriptBundle()
{
    using func_t = void (*)(ScriptBundle*);
    RelocFunc<func_t> func(Addresses::ScriptBundle_ctor);
    func(this);
}

Red::ScriptBundle::~ScriptBundle()
{
    using func_t = void (*)(ScriptBundle*);
    RelocFunc<func_t> func(Addresses::ScriptBundle_dtor);
    func(this);
}

bool Red::ScriptBundle::Read(const CString& aPath)
{
    using func_t = bool (*)(ScriptBundle*, const CString&);
    RelocFunc<func_t> func(Addresses::ScriptBundle_Read);
    return func(this, aPath);
}

Red::DynArray<Red::ScriptDefinition*> Red::ScriptBundle::Collect(bool aDeep) const
{
    DynArray<ScriptDefinition*> definitions;

    for (auto* func : globals)
    {
        definitions.PushBack(func);

        if (aDeep)
        {
            for (auto* param : func->params)
                definitions.PushBack(param);

            for (auto* local : func->localVars)
                definitions.PushBack(local);
        }
    }

    for (auto* type : enums)
    {
        definitions.PushBack(type);
    }

    for (auto* type : bitfields)
    {
        definitions.PushBack(type);
    }

    for (auto* type : classes)
    {
        definitions.PushBack(type);

        if (aDeep)
        {
            for (auto* prop : type->properties)
                definitions.PushBack(prop);

            for (auto* prop : type->overrides)
                definitions.PushBack(prop);

            for (auto* func : type->functions)
            {
                definitions.PushBack(func);

                for (auto* param : func->params)
                    definitions.PushBack(param);

                for (auto* local : func->localVars)
                    definitions.PushBack(local);
            }
        }
    }

    for (auto* type : types)
    {
        definitions.PushBack(type);
    }

    return definitions;
}
