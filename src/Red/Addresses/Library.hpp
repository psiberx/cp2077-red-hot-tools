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

// constexpr uint32_t ISerializable_SetReference = 2587561854;
constexpr uint32_t ISerializable_Clone = 2601784524;

constexpr uint32_t InkDrawArea_GetBoundingRect = 446829303;

constexpr uint32_t InkLayer_AttachLibraryInstance = 2019635589;

constexpr uint32_t inkPointerHandler_Create = 630009171;
constexpr uint32_t inkPointerHandler_Reset = 3695579637;
constexpr uint32_t inkPointerHandler_Override = 4279316794;

constexpr uint32_t InkSpawner_FinishAsyncSpawn = 2488155854;

constexpr uint32_t InkSystem_Instance = 2755465343;
constexpr uint32_t InkSystem_Instance_Pre212a = 2635337807;

constexpr uint32_t InkWidget_Draw = 1737035665;
constexpr uint32_t InkWidget_IsVisible = 3227716428;
constexpr uint32_t InkWidget_SpawnFromLibrary = 111687851;

constexpr uint32_t InkWidgetContext_Clone = 3823045541;
constexpr uint32_t InkWidgetContext_AddWidget = 2526158623;

constexpr uint32_t InkWidgetLibrary_AsyncSpawnFromExternal = 1396063719;
constexpr uint32_t InkWidgetLibrary_AsyncSpawnFromLocal = 118698863;
constexpr uint32_t InkWidgetLibrary_SpawnFromExternal = 506278179;
constexpr uint32_t InkWidgetLibrary_SpawnFromLocal = 1158555307;
constexpr uint32_t InkWidgetLibrary_SpawnRoot = 3160221133;

constexpr uint32_t InkWindow_ctor = 1410271027;
constexpr uint32_t InkWindow_dtor = 1413416760;
constexpr uint32_t InkWindow_TogglePointerInput = 1797656531;
constexpr uint32_t InkWindow_IsPointerVisible = 2091454561;
constexpr uint32_t InkWindow_SetPointerVisibility = 3741389418;
constexpr uint32_t InkWindow_SetPointerWidget = 621352754;

constexpr uint32_t JobHandle_Wait = 1576079097;

constexpr uint32_t NodeRef_Create = 3491172781;

constexpr uint32_t PhysicsTraceResult_GetHitObject = 2394822845;

constexpr uint32_t RenderProxy_SetHighlightParams = 1093803822;
constexpr uint32_t RenderProxy_SetScanningState = 2838044016;
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
