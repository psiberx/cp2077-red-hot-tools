#pragma once

namespace Red::AddressLib
{
constexpr uint32_t Main = 3545369307;
constexpr uint32_t ExecuteProcess = 2203918127; // CProcessRunner::Run
constexpr uint32_t InvokeSCC = 2746819158;
constexpr uint32_t LogChannel = 3083410640;

constexpr uint32_t Camera_ProjectPoint = 1517361120;

constexpr uint32_t CBaseEngine_LoadScripts = 3570081113; // CBaseEngine::LoadScripts
constexpr uint32_t CBaseEngine_MainLoopTick = 1875906465;

constexpr uint32_t EntityID_ToStringDEBUG = 3457552837;

constexpr uint32_t FileSystem_Instance = 3788966949;
constexpr uint32_t FileSystem_Close = 1332290822;

constexpr uint32_t ISerializable_SetReference = 2587561854;

constexpr uint32_t InkSystem_Instance = 2755465343;

constexpr uint32_t InkWidget_Draw = 1737035665;

constexpr uint32_t JobHandle_Wait = 1576079097;

constexpr uint32_t NodeRef_Create = 3491172781;

constexpr uint32_t PhysicsTraceResult_GetHitObject = 2394822845;

constexpr uint32_t RenderProxy_SetHighlightParams = 1093803822;
constexpr uint32_t RenderProxy_SetVisibility = 1790971865;

constexpr uint32_t ResourceBank_ForgetResource = 2288918343;

constexpr uint32_t ResourceDepot_LoadArchives = 2517385486;
constexpr uint32_t ResourceDepot_DestructArchives = 3517657864;
constexpr uint32_t ResourceDepot_RequestResource = 2450934495;

constexpr uint32_t ResourcePath_Create = 3998356057;

constexpr uint32_t ScriptBinder_ResolveNatives = 2952800760;
constexpr uint32_t ScriptBinder_ResolveTypes = 1666326197;
constexpr uint32_t ScriptBinder_CreateClass = 1040327137;
constexpr uint32_t ScriptBinder_CreateProperties = 3630769678;
constexpr uint32_t ScriptBinder_CreateEnum = 4171309343;
constexpr uint32_t ScriptBinder_CreateBitfield = 487007291;
constexpr uint32_t ScriptBinder_CreateFunction = 777921665;
constexpr uint32_t ScriptBinder_TranslateBytecode = 3442875632; // CScriptDataBinder::LoadOpcodes

constexpr uint32_t ScriptBundle_ctor = 3991604425;
constexpr uint32_t ScriptBundle_dtor = 3993832650;
constexpr uint32_t ScriptBundle_Read = 3761639893;
constexpr uint32_t ScriptBundle_Validate = 3482458695;

constexpr uint32_t ScriptValidator_Validate = 898639042;

constexpr uint32_t StreamingSector_dtor = 3420392384;
constexpr uint32_t StreamingSector_OnReady = 3972601611;

constexpr uint32_t Transform_ApplyToBox = 4207022512;

constexpr uint32_t WorldNodeInstance_Initialize = 624308217;
constexpr uint32_t WorldNodeInstance_Attach = 3515291207;
constexpr uint32_t WorldNodeInstance_Detach = 3473806907;
constexpr uint32_t WorldNodeInstance_SetVisibility = 2290487415;
}
