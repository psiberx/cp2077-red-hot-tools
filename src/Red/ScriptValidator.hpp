#pragma once

#include "Addresses.hpp"
#include "ScriptBundle.hpp"
#include "ScriptReport.hpp"

#include <RED4ext/Relocation.hpp>

namespace Red
{
struct ScriptValidator
{
    inline static bool Validate(ScriptBundle& aData, ScriptReport& aReport)
    {
        using func_t = bool (*)(ScriptValidator*, ScriptBundle&, ScriptReport&);
        RelocFunc<func_t> func(Addresses::ScriptValidator_Validate);

        return func(nullptr, aData, aReport);
    }
};
}
