#include "ScriptReporter.hpp"
#include "App/Environment.hpp"
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
    Hook<Raw::CBaseEngine::InvokeSCC>(&OnInvokeSCC);
    Hook<Raw::CBaseEngine::LoadScripts>(&OnLoadScripts);
}

bool App::ScriptReporter::OnInvokeSCC(Red::CString& aSourceDir, Red::CString& aBlobPath, uint8_t aProfile, int64_t a4,
                                      int32_t a5, int32_t a6, Red::CString* aOutput)
{
    const auto compilationTime = std::filesystem::file_time_type::clock::now();
    const auto success = Raw::CBaseEngine::InvokeSCC(aSourceDir, aBlobPath, aProfile, a4, a5, a6, aOutput);

    if (!success)
    {
        const auto logPath = Env::ScriptCompilationLogFile();
        std::string errorMessage;

        if (IsFreshLog(logPath, compilationTime) && ScanForErrorLog(logPath, errorMessage))
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
                *aOutput = Red::CString(errorMessage);
            }
        }
    }

    return success;
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

bool App::ScriptReporter::IsFreshLog(const std::filesystem::path& aPath, auto aCompilationTime)
{
    std::error_code error;
    const auto writeTime = std::filesystem::last_write_time(aPath, error);
    if (error)
        return false;

    return writeTime > aCompilationTime;
}

bool App::ScriptReporter::ScanForErrorLog(const std::filesystem::path& aPath, std::string& aMessage)
{
    constexpr std::string_view ErrorMarker = "[ERROR";

    std::ifstream file(aPath, std::ios::binary);
    if (!file.is_open())
        return false;

    std::string line;
    while (std::getline(file, line))
    {
        if (line.find(ErrorMarker) != std::string::npos)
        {
            aMessage = line;
            return true;
        }
    }

    return false;
}
