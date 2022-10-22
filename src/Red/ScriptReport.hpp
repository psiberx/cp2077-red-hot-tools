#pragma once

#include <cstdarg>
#include <cstdint>
#include <RED4ext/Common.hpp>
#include <RED4ext/CString.hpp>
#include <RED4ext/DynArray.hpp>

namespace Red
{
struct ScriptReport
{
    ScriptReport() noexcept
        : errors(&unk10)
        , maxErrors(0)
        , fillErrors(true)
    {
    }

    ScriptReport(DynArray<CString>& aErrors, uint32_t aMaxErrors = 0) noexcept
        : errors(&aErrors)
        , maxErrors(aMaxErrors)
        , fillErrors(true)
    {
    }

    virtual ~ScriptReport() = default;

    virtual void AddValidationError(const char* aFormat, ...)
    {
        if (errors && fillErrors)
        {
            std::va_list args;
            va_start(args, aFormat);
            errors->PushBack(Format(aFormat, args));
            va_end(args);
        }
    }

    virtual void AddBindingError(const char* aFormat, ...)
    {
        if (errors && fillErrors)
        {
            std::va_list args;
            va_start(args, aFormat);
            errors->PushBack(Format(aFormat, args));
            va_end(args);
        }
    }

    [[nodiscard]] inline bool HasErrors() const noexcept
    {
        return errors && errors->size > 0;
    }

    [[nodiscard]] inline CString ToString() const noexcept
    {
        if (!errors || errors->size == 0)
        {
            return {};
        }

        std::string str;
        bool eol = false;

        for (const auto& error : *errors)
        {
            if (eol)
            {
                str.append("\n");
            }

            str.append(error.c_str());
            eol = true;
        }

        return str.c_str();
    }

    inline static CString Format(const char* aFormat, std::va_list aArgs)
    {
        char buffer[4096];
        vsnprintf(buffer, sizeof(buffer), aFormat, aArgs);
        return buffer;
    }

    bool fillErrors;           // 08 - Usually equals to CBaseEngine::scriptsSilentValidation
    DynArray<CString> unk10;   // 10 - Seems to be unused by the game
    DynArray<CString>* errors; // 20 - Usually points to CBaseEngine::scriptsValidationErrors
    uint32_t maxErrors;        // 28
};
RED4EXT_ASSERT_SIZE(ScriptReport, 0x30);
RED4EXT_ASSERT_OFFSET(ScriptReport, fillErrors, 0x08);
RED4EXT_ASSERT_OFFSET(ScriptReport, errors, 0x20);
RED4EXT_ASSERT_OFFSET(ScriptReport, maxErrors, 0x28);
}
