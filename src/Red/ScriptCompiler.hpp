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
    Final = 8,     // final.redscripts | -no-testonly -no-breakpoint -no-exec -no-debug -profile=off -optimize
    NoOpts = 16,   // final_noopts.redscripts | -no-testonly -no-breakpoint -no-exec -no-debug -profile=off
};

struct ScriptCompiler
{
    // inline static bool Compile(CString& aSourceDir, CString& aBlobPath)
    // {
    //     return InvokeSCC(aSourceDir, aBlobPath, EScriptProfile::Final, 0, 0, 0, nullptr);
    // }

    inline static bool Compile()
    {
        using func_t = bool(*)(void* a1, const CString& aCommand, void*, void*, char);
        RelocFunc<func_t> func(Addresses::ExecuteProcess);

        return func(nullptr, "scc.exe", nullptr, nullptr, 0);
    }

    inline static bool Compile(CString& aSourceDir, CString& aBlobPath, CString& aOutput)
    {
        return InvokeSCC(aSourceDir, aBlobPath, EScriptProfile::Final, 0, 0, 0, &aOutput);
    }

    inline static bool InvokeSCC(CString& aSourceDir, CString& aBlobPath, EScriptProfile aProfile,
                                 int64_t a4, int32_t a5, int32_t a6, CString* aOutput)
    {
        using func_t = decltype(&InvokeSCC);
        RelocFunc<func_t> func(Addresses::InvokeSCC);

        return func(aSourceDir, aBlobPath, aProfile, a4, a5, a6, aOutput);
    }
};
}
