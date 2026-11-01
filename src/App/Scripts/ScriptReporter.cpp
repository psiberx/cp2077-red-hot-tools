#include "ScriptReporter.hpp"
#include "Red/GameEngine.hpp"

void App::ScriptReporter::ShowErrorBox(const char* aCaption, const char* aMessage)
{
    auto engine = Red::CGameEngine::Get();
    auto hWnd = engine->unkD0 ? reinterpret_cast<HWND>(engine->unkD0->hWnd) : nullptr;

    MessageBoxA(hWnd, aMessage, aCaption, MB_SYSTEMMODAL | MB_ICONERROR);
}

void App::ScriptReporter::ShowErrorBox(const char* aCaption, const std::string& aMessage)
{
    ShowErrorBox(aCaption, aMessage.c_str());
}

void App::ScriptReporter::ShowErrorBox(const char* aCaption, const Red::CString& aMessage)
{
    ShowErrorBox(aCaption, aMessage.c_str());
}

void App::ScriptReporter::ShowErrorBox(const char* aCaption, const Red::DynArray<Red::CString>& aMessages)
{
    std::string message;

    bool eol = false;
    for (const auto& entry : aMessages)
    {
        if (eol)
        {
            message.append("\n");
        }

        message.append(entry.c_str());
        eol = true;
    }

    ShowErrorBox(aCaption, message.c_str());
}

void App::ScriptReporter::OnBootstrap()
{
    HookAfter<Raw::CBaseEngine::InvokeSCC>(&OnInvokeSCC);
    // Hook<Raw::CBaseEngine::LoadScripts>(&OnLoadScripts);
}

void App::ScriptReporter::OnInvokeSCC(bool& aSuccess, Red::CString& aSourceDir, Red::CString& aBlobPath,
                                      uint8_t aProfile, int64_t a4, int32_t a5, int32_t a6, Red::CString* aOutput)
{
    if (!aSuccess)
    {
        if (!aOutput)
        {
            if (auto engine = Red::CGameEngine::Get())
            {
                aOutput = &engine->scriptsCompilationErrors;
            }
        }

        if (aOutput && aOutput->Length() == 0)
        {
            *aOutput = "Scripts compilation failed";
        }
    }
}

bool App::ScriptReporter::OnLoadScripts(Red::CBaseEngine& aEngine, Red::CString& aPath, uint64_t aTimestamp,
                                        uint64_t a4)
{
    // This is a fallback mode which never works for the release game
    if (!aTimestamp)
        return false;

    if (aEngine.scriptsCompilationErrors.Length() > 0)
    {
        ExitProcess(0xDEAD);
        return false;
    }

    // When enabled the errors will be added to the CBaseEngine::scriptsValidationErrors
    aEngine.scriptsSilentValidation = true;

    bool success = Raw::CBaseEngine::LoadScripts(aEngine, aPath, aTimestamp, a4);

    if (!success && !aEngine.scriptsValidationErrors.IsEmpty())
    {
        ExitProcess(0xDEAD);
        return false;
    }

    return success;
}
