#pragma once

#include "ScriptBundle.hpp"
#include "ScriptReport.hpp"

#include <functional>
#include <RED4ext/DynArray.hpp>
#include <RED4ext/RTTISystem.hpp>

namespace Red
{
struct ScriptFile
{
    uint32_t hash;
    uint32_t crc;
    CString path;
};

using FileResolver = std::function<ScriptFile*(uint32_t)>;

struct ScriptBinder
{
    ScriptBinder(CRTTISystem* aRtti, const FileResolver& aFileResolver);

    // bool Bind(ScriptBundle& aData, ScriptReport& aReport);
    bool ResolveNatives(DynArray<ScriptDefinition*>& aDefinitions, ScriptReport& aReport);
    void ResolveTypes(DynArray<ScriptDefinition*>& aDefinitions);
    bool CreateClass(ScriptClass* aClass, ScriptReport& aReport);
    bool CreateEnum(ScriptEnum* aEnum, ScriptReport& aReport);
    bool CreateBitfield(ScriptBitfield* aBitfield, ScriptReport& aReport);
    bool CreateProperties(ScriptClass* aClass, ScriptReport& aReport);
    bool CreateFunction(ScriptFunction* aFunc, ScriptReport& aReport);
    void TranslateBytecode(DynArray<ScriptDefinition*>& aDefinitions);

    CRTTISystem* rtti;
    FileResolver fileResolver;
};
}
