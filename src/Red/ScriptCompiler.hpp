#pragma once

#include "Addresses.hpp"

#include <RED4ext/CString.hpp>
#include <RED4ext/Relocation.hpp>

namespace Red
{
enum class EScriptProfile : uint8_t
{
    Master = 0,    // master.redscripts | -profile=on
    Profiling = 2, // profiling.redscripts | -no-breakpoint -profile=on
    Final = 4,     // final.redscripts | -no-testonly -no-breakpoint -profile=off -optimize
    NoOpts = 16,   // final_noopts.redscripts | -no-testonly -no-breakpoint -profile=off
};

struct ScriptCompiler
{
    inline static bool Compile(CString& aSourceDir, CString& aBlobPath)
    {
        return InvokeSCC(aSourceDir, aBlobPath, EScriptProfile::Final, true, false, nullptr);
    }

    inline static bool Compile(CString& aSourceDir, CString& aBlobPath, CString& aOutput)
    {
        return InvokeSCC(aSourceDir, aBlobPath, EScriptProfile::Final, true, true, &aOutput);
    }

    inline static bool InvokeSCC(CString& aSourceDir, CString& aBlobPath, EScriptProfile aProfile, bool aSilent,
                                 bool aFillOutputOnError, CString* aOutput)
    {
        using func_t = decltype(&InvokeSCC);
        RelocFunc<func_t> func(Addresses::InvokeSCC);

        return func(aSourceDir, aBlobPath, aProfile, aSilent, aFillOutputOnError, aOutput);
    }
};
}
