#pragma once

#include "ScriptBundle.hpp"
#include "ScriptReport.hpp"

namespace Red
{
struct ScriptValidator
{
    inline static bool Validate(ScriptBundle& aData, ScriptReport& aReport)
    {
        using func_t = bool (*)(ScriptValidator*, ScriptBundle&, ScriptReport&);
        static UniversalRelocFunc<func_t> func(AddressLib::ScriptValidator_Validate);

        return func(nullptr, aData, aReport);
    }
};
}
