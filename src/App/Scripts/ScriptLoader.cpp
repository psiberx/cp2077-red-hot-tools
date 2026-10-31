#include "ScriptLoader.hpp"
#include "App/Environment.hpp"
#include "App/Scripts/ObjectRegistry.hpp"
#include "App/Scripts/ScriptReporter.hpp"
#include "Core/Facades/Container.hpp"
#include "Red/EngineConfig.hpp"
#include "Red/GameEngine.hpp"
#include "Red/RawDynArray.hpp"
#include "Red/ScriptBinder.hpp"
#include "Red/ScriptBundle.hpp"
#include "Red/ScriptCompiler.hpp"
#include "Red/ScriptReport.hpp"
#include "Red/ScriptValidator.hpp"

App::ScriptLoader::ScriptLoader(std::filesystem::path aSourceDir, std::filesystem::path aCachePath)
    : m_scriptSourceDir(std::move(aSourceDir))
    , m_scriptBlobPath(std::move(aCachePath))
{
}

bool App::ScriptLoader::CanReloadScripts()
{
    auto engine = Red::CGameEngine::Get();

    if (!engine || engine->engineState != Red::EEngineState::Running)
        return false;

    return Red::EngineConfig::Get()->GetValue<bool>("Scripts", "EnableCompilation");
}

void App::ScriptLoader::ReloadScripts()
{
    if (!CanReloadScripts())
        return;

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

bool App::ScriptLoader::CompileScripts(Red::ScriptBundle& aBundle, bool aInjectCustomCacheArg)
{
    auto engine = Red::CGameEngine::Get();

    Red::CString sourceDir(m_scriptSourceDir.string().c_str());
    Red::CString blobPath(m_scriptBlobPath.string().c_str());

    if (engine->scriptsBlobPath.Length() > 0)
    {
        blobPath = engine->scriptsBlobPath;
    }

    LogInfo(R"([ScriptLoader] Compiling scripts from "{}" as "{}"...)", sourceDir.c_str(), blobPath.c_str());

    if (blobPath.Length() > 0 && aInjectCustomCacheArg)
    {
        auto argInjection = std::format("{}\" -customCacheDir \"{}", sourceDir.c_str(),
                                        std::filesystem::path(blobPath.c_str()).parent_path().string());
        sourceDir = argInjection.c_str();
    }

    if (!Red::ScriptCompiler::Compile(/*sourceDir, blobPath, engine->scriptsCompilationErrors*/))
    {
        LogError("[ScriptLoader] Scripts compilation failed.");
        return false;
    }

    LogInfo("[ScriptLoader] Reading script blob from \"{}\"...", blobPath.c_str());

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
        if (scriptClass->rttiClass)
        {
            continue;
        }

        scriptClass->rttiClass = rtti->GetClass(scriptClass->name);

        if (!scriptClass->rttiClass)
        {
            if (!scriptClass->flags.isNative)
            {
                binder.CreateClass(scriptClass, aReport);
            }
        }
    }

    for (auto& scriptEnum : aBundle.enums)
    {
        if (scriptEnum->rttiEnum)
        {
            continue;
        }

        scriptEnum->rttiEnum = rtti->GetEnumByScriptName(scriptEnum->name);

        if (!scriptEnum->rttiEnum)
        {
            if (!scriptEnum->isNative)
            {
                binder.CreateEnum(scriptEnum, aReport);
            }
        }
    }

    for (auto& scriptBitfield : aBundle.bitfields)
    {
        if (scriptBitfield->isNative)
            continue;

        auto* rttiBitfield = rtti->GetBitfield(scriptBitfield->name);

        if (!rttiBitfield)
        {
            binder.CreateBitfield(scriptBitfield, aReport);
        }
    }

    binder.ResolveTypes(definitions);

    Red::DynArray<Red::ScriptDefinition*> scriptFuncs;
    Core::Set<Red::CBaseFunction*> resolvedFuncs;

    for (auto& definition : definitions)
    {
        if (definition->GetType() != Red::EScriptDefinition::Function)
            continue;

        auto scriptFunc = reinterpret_cast<Red::ScriptFunction*>(definition);

        if (!scriptFunc->rttiFunc)
        {
            ResolveFunction(scriptFunc, rtti);
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
                if (Red::IsSpecial(rttiFunc))
                {
                    continue;
                }

                rttiFunc->bytecode.bytecode.buffer.Clear();
            }
        }
    }

    for (auto* scriptClass : aBundle.classes)
    {
        ClearScriptedProperties(scriptClass->rttiClass);
        binder.CreateProperties(scriptClass, aReport);
    }

    rtti->SetStringTable(aBundle.strings);

    LogInfo("[ScriptLoader] Translating bytecode...");

    binder.TranslateBytecode(scriptFuncs);

    LogInfo("[ScriptLoader] Initializing runtime...");

    for (auto& scriptClass : aBundle.classes)
    {
        auto& listeners = scriptClass->rttiClass->listeners;

        for (uint32_t i = listeners.Size(); i > 0; --i)
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
    auto* memberFuncs = reinterpret_cast<Red::RawDynArray<void>*>(&aClass->funcs);
    auto* staticFuncs = reinterpret_cast<Red::RawDynArray<void>*>(&aClass->staticFuncs);
    const auto numMemberFuncs = memberFuncs->size;
    const auto numStaticFuncs = staticFuncs->size;

    memberFuncs->size = 0;
    staticFuncs->size = 0;

    const auto unkE0 = aClass->unkE0;
    aClass->unkE0 = 0;
    aClass->ClearScriptedData();
    aClass->unkE0 = unkE0;

    memberFuncs->size = numMemberFuncs;
    staticFuncs->size = numStaticFuncs;
}

void App::ScriptLoader::ResolveFunction(Red::ScriptFunction* aScriptFunc, Red::CRTTISystem* aRtti,
                                        Red::CClass* aRttiClass)
{
    if (!aScriptFunc->parent)
    {
        aScriptFunc->rttiFunc = aRtti->GetFunction(aScriptFunc->name);
        return;
    }

    if (!aRttiClass)
    {
        aRttiClass = aScriptFunc->parent->rttiClass;
    }

    for (auto rttiFunc : aRttiClass->funcs)
    {
        // if (rttiFunc->flags.isNative != aScriptFunc->flags.isNative)
        //     continue;

        if (rttiFunc->fullName == aScriptFunc->name)
        {
            aScriptFunc->rttiFunc = rttiFunc;
            return;
        }
    }

    for (auto rttiFunc : aRttiClass->staticFuncs)
    {
        // if (rttiFunc->flags.isNative != aScriptFunc->flags.isNative)
        //     continue;

        if (rttiFunc->fullName == aScriptFunc->name)
        {
            aScriptFunc->rttiFunc = rttiFunc;
            return;
        }
    }

    if (aScriptFunc->flags.isStatic)
    {
        std::string fullName;
        fullName.append(aRttiClass->name.ToString());
        fullName.append("::");
        fullName.append(aScriptFunc->name.ToString());

        aScriptFunc->rttiFunc = aRtti->GetFunction(fullName.c_str());

        if (aScriptFunc->rttiFunc)
        {
            return;
        }
    }

    if (aRttiClass->parent)
    {
        ResolveFunction(aScriptFunc, aRtti, aRttiClass->parent);
    }
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
