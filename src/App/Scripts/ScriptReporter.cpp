#include "ScriptReporter.hpp"
#include "Red/EngineConfig.hpp"
#include "Red/GameEngine.hpp"

App::ScriptReporter::ScriptReporter(bool aCompatMode)
    : m_compatMode(aCompatMode)
{
}

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
    Hook<Raw::CBaseEngine::LoadScripts>(&ScriptReporter::OnLoadScripts);
}

bool App::ScriptReporter::OnLoadScripts(Red::CBaseEngine& aEngine, Red::CString& aPath,
                                        uint64_t aTimestamp, uint64_t a4)
{
    // This is a fallback mode which never works for the release game
    if (!aTimestamp)
        return false;

    const auto compilationEnabled = Red::EngineConfig::Get()->GetValue<bool>("Scripts", "EnableCompilation");
    if (aEngine.scriptsCompilationErrors.Length() > 0 || (compilationEnabled && aEngine.scriptsBlobPath.Length() == 0))
    {
        ExitProcess(0xDEAD);
        return false;
    }

    // When enabled the errors will be added to the CBaseEngine::scriptsValidationErrors
    aEngine.scriptsSilentValidation = true;

    bool success = Raw::CBaseEngine::LoadScripts(aEngine, aPath, aTimestamp, a4);

    if (!success && aEngine.scriptsValidationErrors.size > 0)
    {
        ShowErrorBox("Validation error", aEngine.scriptsValidationErrors);
        ExitProcess(0xDEAD);
        return false;
    }

    return success;
}
