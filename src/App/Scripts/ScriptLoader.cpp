#include "ScriptLoader.hpp"
#include "App/Environment.hpp"
#include "App/Scripts/ScriptReporter.hpp"
#include "App/Scripts/ObjectRegistry.hpp"
#include "Core/Facades/Container.hpp"
#include "Red/GameEngine.hpp"
#include "Red/ScriptCompiler.hpp"
#include "Red/ScriptBinder.hpp"
#include "Red/ScriptBundle.hpp"
#include "Red/ScriptReport.hpp"
#include "Red/ScriptValidator.hpp"

App::ScriptLoader::ScriptLoader(std::filesystem::path aSourceDir,
                                std::filesystem::path aCachePath)
    : m_scriptSourceDir(std::move(aSourceDir))
    , m_scriptBlobPath(std::move(aCachePath))
{
}

bool App::ScriptLoader::CanReloadScripts()
{
    auto engine = Red::CGameEngine::Get();

    return engine && engine->engineState == Red::EEngineState::Running;
}

void App::ScriptLoader::ReloadScripts()
{
    if (CanReloadScripts())
    {
        LogInfo("[ScriptLoader] Scripts reload requested.");

        HookOnceAfter<Raw::CBaseEngine::MainLoopTick>([this]() {
            Red::ScriptBundle bundle;
            Red::ScriptReport report;

            if (!CompileScripts(bundle, true))
                return;

            if (!ValidateScripts(bundle, report))
            {
                ShowErrorBox("Validation error", report.ToString());
                return;
            }

            CaptureScriptableData();

            if (!BindScripts(bundle, report))
            {
                ShowErrorBox("Binding error", report.ToString());
                return;
            }

            RestoreScriptableData();

            if (report.HasErrors())
            {
                LogWarning("[ScriptLoader] {}", report.ToString().c_str());
            }

            LogInfo("[ScriptLoader] Scripts reload completed.");
        });
    }
}

bool App::ScriptLoader::CompileScripts(Red::ScriptBundle& aBundle, bool aInjectCustomCacheArg)
{
    auto engine = Red::CGameEngine::Get();

    Red::CString sourceDir(m_scriptSourceDir.string().c_str());
    Red::CString blobPath(m_scriptBlobPath.string().c_str());

    if (engine->scriptsBlobPath.Length() > 0)
    {
        blobPath = engine->scriptsBlobPath;
    }

    LogInfo("[ScriptLoader] Compiling scripts from [{}] as [{}]...", sourceDir.c_str(), blobPath.c_str());

    if (engine->scriptsBlobPath.Length() > 0 && aInjectCustomCacheArg)
    {
        auto argInjection = std::format("{}\" -customCacheDir \"{}", sourceDir.c_str(),
                                        std::filesystem::path(blobPath.c_str()).parent_path().string());
        sourceDir = argInjection.c_str();
    }

    if (!Red::ScriptCompiler::Compile(sourceDir, blobPath, engine->scriptsCompilationErrors))
    {
        LogError("[ScriptLoader] Scripts compilation failed.");
        return false;
    }

    LogInfo("[ScriptLoader] Reading script blob from [{}]...", blobPath.c_str());

    if (!aBundle.Read(blobPath))
    {
        LogError("[ScriptLoader] Script blob has invalid format.");
        return false;
    }

    return true;
}


bool App::ScriptLoader::ValidateScripts(Red::ScriptBundle& aBundle, Red::ScriptReport& aReport)
{
    LogInfo("[ScriptLoader] Validating scripts...");

    if (!Red::ScriptValidator::Validate(aBundle, aReport))
    {
        LogError(aReport.ToString().c_str());
        return false;
    }

    return true;
}

bool App::ScriptLoader::BindScripts(Red::ScriptBundle& aBundle, Red::ScriptReport& aReport)
{
    LogInfo("[ScriptLoader] Binding scripts...");

    auto rtti = Red::CRTTISystem::Get();
    auto fileResolver = +[](uint32_t) { return nullptr; };
    auto definitions = aBundle.Collect(true);

    Red::ScriptBinder binder(rtti, fileResolver);

    if (!binder.ResolveNatives(definitions, aReport))
    {
        LogError(aReport.ToString().c_str());
        return false;
    }

    for (auto& scriptClass : aBundle.classes)
    {
        if (scriptClass->flags.isNative)
            continue;

        scriptClass->rttiClass = rtti->GetClass(scriptClass->name);

        if (!scriptClass->rttiClass)
        {
            binder.CreateClass(scriptClass, aReport);
        }
    }

    for (auto& scriptEnum : aBundle.enums)
    {
        if (scriptEnum->isNative)
            continue;

        scriptEnum->rttiEnum = rtti->GetEnumByScriptName(scriptEnum->name);

        if (!scriptEnum->rttiEnum)
        {
            binder.CreateEnum(scriptEnum, aReport);
        }
        else
        {
            for (auto* scriptConstant : scriptEnum->constants)
            {
                bool resolved = false;

                for (uint32_t i = 0; i < scriptEnum->rttiEnum->hashList.size; ++i)
                {
                    if (scriptConstant->name == scriptEnum->rttiEnum->hashList[i])
                    {
                        resolved = true;
                        break;
                    }
                }

                if (!resolved)
                {
                    scriptEnum->rttiEnum->hashList.PushBack(scriptConstant->name);
                    scriptEnum->rttiEnum->valueList.PushBack(scriptConstant->value);
                }
            }
        }
    }

    for (auto& scriptBitfield : aBundle.bitfields)
    {
        if (scriptBitfield->isNative)
            continue;

        scriptBitfield->rttiBitfield = rtti->GetBitfield(scriptBitfield->name);

        if (!scriptBitfield->rttiBitfield)
        {
            binder.CreateBitfield(scriptBitfield, aReport);
        }
    }

    binder.ResolveTypes(definitions);

    for (auto* scriptClass : aBundle.classes)
    {
        ClearScriptedProperties(scriptClass->rttiClass);
        binder.CreateProperties(scriptClass, aReport);
    }

    Red::DynArray<Red::ScriptDefinition*> scriptFuncs;
    Core::Set<Red::CBaseFunction*> resolvedFuncs;

    for (auto& definition : definitions)
    {
        if (definition->GetType() != Red::EScriptDefinition::Function)
            continue;

        auto scriptFunc = reinterpret_cast<Red::ScriptFunction*>(definition);

        if (!scriptFunc->rttiFunc)
        {
            if (!scriptFunc->parent)
            {
                scriptFunc->rttiFunc = rtti->GetFunction(scriptFunc->name);
            }
            else
            {
                auto scriptClass = scriptFunc->parent;

                if (!scriptFunc->flags.isStatic)
                {
                    for (auto rttiFunc : scriptClass->rttiClass->funcs)
                    {
                        if (rttiFunc->fullName == scriptFunc->name)
                        {
                            scriptFunc->rttiFunc = rttiFunc;
                            break;
                        }
                    }

                    if (!scriptFunc->rttiFunc)
                    {
                        for (auto rttiFunc : scriptClass->rttiClass->funcs)
                        {
                            if (rttiFunc->shortName == scriptFunc->shortName)
                            {
                                scriptFunc->rttiFunc = rttiFunc;
                                break;
                            }
                        }
                    }
                }
                else if (scriptFunc->flags.isNative)
                {
                    for (auto rttiFunc : scriptClass->rttiClass->staticFuncs)
                    {
                        if (rttiFunc->shortName == scriptFunc->shortName)
                        {
                            scriptFunc->rttiFunc = rttiFunc;
                            break;
                        }
                    }
                }
                else
                {
                    std::string fullName;
                    fullName.append(scriptClass->rttiClass->name.ToString());
                    fullName.append("::");
                    fullName.append(scriptFunc->name.ToString());

                    scriptFunc->rttiFunc = rtti->GetFunction(fullName.c_str());
                }
            }
        }

        binder.CreateFunction(scriptFunc, aReport);

        if (!scriptFunc->flags.isNative)
        {
            scriptFuncs.PushBack(scriptFunc);
            resolvedFuncs.insert(scriptFunc->rttiFunc);
        }
    }

    {
        Red::DynArray<Red::CBaseFunction*> rttiFuncs;
        rtti->GetClassFunctions(rttiFuncs);

        for (auto rttiFunc : rttiFuncs)
        {
            if (!rttiFunc->flags.isNative && !resolvedFuncs.contains(rttiFunc))
            {
                using FlagsIntType = uint32_t;
                constexpr auto CustomFlag = 1 << (sizeof(FlagsIntType) - 1);
                static_assert(sizeof(Red::CBaseFunction::Flags) == sizeof(FlagsIntType));

                if (*reinterpret_cast<FlagsIntType*>(&rttiFunc->flags) & CustomFlag)
                    continue;

                // TODO: Find a way to properly destroy the buffer.
                auto& codeBuffer = rttiFunc->bytecode.bytecode.buffer;
                codeBuffer.data = nullptr;
                codeBuffer.size = 0;
            }
        }
    }

    rtti->SetStringTable(aBundle.strings);

    LogInfo("[ScriptLoader] Translating bytecode...");

    binder.TranslateBytecode(scriptFuncs);

    LogInfo("[ScriptLoader] Initializing runtime...");

    for (auto& scriptClass : aBundle.classes)
    {
        auto& listeners = scriptClass->rttiClass->listeners;

        for (uint32_t i = listeners.size; i > 0; --i)
        {
            if (listeners[i - 1].isScripted)
            {
                listeners.RemoveAt(i - 1);
            }
        }
    }

    rtti->InitializeScriptRuntime();

    return true;
}

bool App::ScriptLoader::HasScriptedProperties(Red::CClass* aClass)
{
    for (const auto& prop : aClass->props)
    {
        if (prop->flags.isScripted)
        {
            return true;
        }
    }

    return false;
}

void App::ScriptLoader::ClearScriptedProperties(Red::CClass* aClass)
{
    const auto numMemberFuncs = aClass->funcs.size;
    const auto numStaticFuncs = aClass->staticFuncs.size;

    aClass->funcs.size = 0;
    aClass->staticFuncs.size = 0;

    aClass->ClearScriptedData();

    aClass->funcs.size = numMemberFuncs;
    aClass->staticFuncs.size = numStaticFuncs;
}

void App::ScriptLoader::CaptureScriptableData()
{
    LogInfo("[ScriptLoader] Capturing scriptable data...");

    Core::Resolve<ObjectRegistry>()->CreateSnapshot();
}

void App::ScriptLoader::RestoreScriptableData()
{
    LogInfo("[ScriptLoader] Restoring scriptable data...");

    Core::Resolve<ObjectRegistry>()->RestoreSnapshot();
}

void App::ScriptLoader::ShowErrorBox(const char* aCaption, const Red::CString& aMessage)
{
    Core::Resolve<ScriptReporter>()->ShowErrorBox(aCaption, aMessage);
}
