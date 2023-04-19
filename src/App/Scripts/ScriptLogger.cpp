#include "ScriptLogger.hpp"
#include "Red/Logger.hpp"

void App::ScriptLogger::OnBootstrap()
{
    HookBefore<Raw::LogChannel>(&OnLogChannel);
}

void App::ScriptLogger::OnLogChannel(void*, Red::CStackFrame* aFrame, void*, void*)
{
    const auto rewind = aFrame->code;

    Red::CName channel;
    Red::GetParameter(aFrame, &channel);

    if (channel == "DEBUG")
    {
        Red::ScriptRef<Red::CString> message;
        Red::GetParameter(aFrame, &message);

        LogInfo(message.ref->c_str());
    }

    aFrame->code = rewind;
    aFrame->currentParam = 0;
}
