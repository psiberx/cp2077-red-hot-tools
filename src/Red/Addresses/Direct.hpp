#pragma once

// Generated by cp77ida.py on 2024-02-06 for Cyberpunk 2077 v..11
// DO NOT MODIFY. USE tools\ida\scan.py TO GENERATE THIS FILE.

#include <cstdint>

namespace Red::Address
{
constexpr uintptr_t ImageBase = 0x140000000;

constexpr uintptr_t Main = 0x1406A4828 - ImageBase; // 40 55 53 48 8D AC 24 ? ? ? ? 48 81 EC ? ? ? ? FF 15 ? ? ? ? E8, expected: 1, index: 0
constexpr uintptr_t ExecuteProcess = 0x1407339F0 - ImageBase; // 48 89 5C 24 ? 48 89 74 24 ? 57 48 81 EC ? ? ? ? 41 81 79, expected: 1, index: 0
constexpr uintptr_t InvokeSCC = 0x14072E448 - ImageBase; // 48 8B C4 48 89 58 ? 48 89 70 ? 48 89 78 ? 55 41 56 41 57 48 8D A8 ? ? ? ? B8 ? ? ? ? E8 ? ? ? ? 48 2B E0 41 8A D8 4C 8B F2, expected: 1, index: 0
constexpr uintptr_t LogChannel = 0x140CC91C8 - ImageBase; // 48 89 5C 24 08 48 89 74 24 18 55 48 8B EC 48 83 EC 70 48 8B 02 48 8D 35 ? ? ? ? 48 83 65 18 00 4C 8D 45 18 48 83 62 30 00 45 33 C9 48 83 62 38 00, expected: 2, index: 0

constexpr uintptr_t Camera_ProjectPoint = 0x140580300 - ImageBase; // 40 55 48 8D 6C 24 ? 48 81 EC ? ? ? ? 0F 10 41 ? 4D 8B C8 0F 10 49 ? 4C 8D 81 ? ? ? ? 0F 29 45, expected: 1, index: 0

constexpr uintptr_t CBaseEngine_LoadScripts = 0x1400FEBB0 - ImageBase; // 48 89 5C 24 ? 48 89 6C 24 ? 48 89 74 24 ? 57 41 56 41 57 48 83 EC ? 49 8D 99, expected: 1, index: 0
constexpr uintptr_t CBaseEngine_MainLoopTick = 0x1401D841C - ImageBase; // 48 8B C4 55 53 56 57 41 54 41 56 41 57 48 8D 68 ? 48 81 EC ? ? ? ? 0F 29 70 ? 48 8B F1 48 8D 4D ? 0F 29 78, expected: 1, index: 0

constexpr uintptr_t EntityID_ToStringDEBUG = 0x140E5F6E4 - ImageBase; // 40 53 48 83 EC ? 4C 8B 01 48 8B DA 49 F7 C0 ? ? ? ? 75 ? 48 8D 15 ? ? ? ? 48 8B CB E8 ? ? ? ? 48 8B C3 48 83 C4 ? 5B, expected: 1, index: 0

constexpr uintptr_t FileSystem_Instance = 0x1433844D8 - ImageBase; // 48 89 05 ? ? ? ? 48 83 C4 ? 5F C3, expected: 6, index: 1, offset: 3
constexpr uintptr_t FileSystem_Close = 0x14071D9F4 - ImageBase; // 48 89 5C 24 ? 57 48 83 EC ? 48 8B 39 48 85 FF 74 ? 48 8B 07 48 8B CF FF 10 4C 8B  07 33 D2 48 8B CF 48 8B D8 41 FF 50 08, expected: 1, index: 0

constexpr uintptr_t ISerializable_SetReference = 0x14011C4B4 - ImageBase; // 40 53 48 83 EC ? 4C 8B 42 ? 48 8B D9 48 8B 0A 4D 85 C0 74 ? F0 41 FF 40 ? 48 8B 43 ? 48 89 44 24 ? 48 8B 03 48 89 0B 48, expected: 1, index: 0

constexpr uintptr_t JobHandle_Wait = 0x140456ABC - ImageBase; // 48 8B 11 41 83 C9 FF 48 8B 0D ? ? ? ? 45 33 C0 E9, expected: 1, index: 0

constexpr uintptr_t NodeRef_Create = 0x140131310 - ImageBase; // 48 89 5C 24 ? 44 88 44 24 ? 55 56 57 41 54 41 55 41 56 41 57 48 8B EC 48 83 EC ? 8B 72 08 4C 8B F1 85 F6, expected: 1, index: 0

constexpr uintptr_t PhysicsTraceResult_GetHitObject = 0x14022E634 - ImageBase; // 48 89 5C 24 ? 57 48 83 EC ? 41 8B F8 48 8B D9 48 8B 0D ? ? ? ? 44 8B C2 48 8D 54 24 ? E8 ? ? ? ? 4C 8B 4C 24 ? 4D 85 C9, expected: 1, index: 0

constexpr uintptr_t RenderProxy_SetHighlightParams = 0x14097A560 - ImageBase; // 40 53 48 83 EC ? 44 8A 5A ? 4C 8B D2 48 8B D9 45 84 DB 0F 84 ? ? ? ? 8A 02 44 8A 42 ? F6 D8 1A C9 80 E1, expected: 1, index: 0
constexpr uintptr_t RenderProxy_SetVisibility = 0x140426974 - ImageBase; // 8A 41 ? 02 D2 44 8A C0 4C 8B C9 41 80 E0 ? 44 0A C2 B2 ? 22 C2 44 88 41 ? 3A C2 0F 94 C1 44 22 C2 44 3A C2, expected: 1, index: 0

constexpr uintptr_t ResourceBank_ForgetResource = 0x1406A3D18 - ImageBase; // 48 8B C4 48 89 58 ? 48 89 70 ? 4C 89 40 ? 55 57 41 56 48 8D 68 ? 48 81 EC ? ? ? ? 48 8D 99 ? ? ? ? 4C 8B F1, expected: 1, index: 0

constexpr uintptr_t ResourceDepot_LoadArchives = 0x1405F14CC - ImageBase; // 4C 89 4C 24 ? 48 89 4C 24 ? 55 53 56 57 41 55 41 56 41 57 48 8D 6C 24 ? 48 81 EC ? ? ? ? 45 8B 78 ?, expected: 1, index: 0
constexpr uintptr_t ResourceDepot_DestructArchives = 0x14085276C - ImageBase; // 85 D2 74 ? 48 89 5C 24 ? 57 48 83 EC ? 8D 42 ? 8B DA 48 8D 3C 80 48 C1 E7 ? 48 03 F9 48 8B CF 48 83 EF ? E8 ? ? ? ? 83 C3 ? 75, expected: 22, index: 10
constexpr uintptr_t ResourceDepot_RequestResource = 0x1402B3F6C - ImageBase; // 4C 89 4C 24 ? 48 89 54 24 ? 55 53 56 57 41 54 41 55 41 56 41 57 48 8D 6C 24 ? 48 81 EC ? ? ? ? 48 8D B1, expected: 1, index: 0

constexpr uintptr_t ResourcePath_Create = 0x14013087C - ImageBase; // 40 53 48 81 EC ? ? ? ? 83 7A 08 00 48 8B D9 74 ? F2 0F 10 02 48 8D 4C 24 ? 8B 42 08 48 8D 54 24 ? F2 0F 11 44 24, expected: 1, index: 0

constexpr uintptr_t ScriptBinder_ResolveNatives = 0x1403873B4 - ImageBase; // 48 89 5C 24 ? 55 56 57 41 54 41 55 41 56 41 57 48 8B EC 48 83 EC ? 48 8B 3A 4D 8B F8 8B 42 ? 4C 8B E1 48 8D 04 C7 48 89 45, expected: 1, index: 0
constexpr uintptr_t ScriptBinder_ResolveTypes = 0x1408574A4 - ImageBase; // 40 53 55 56 57 41 54 41 56 41 57 48 83 EC ? 48 8B 1A 48 8B E9 8B 42 ? 4C 8D 24 C3 49 3B DC 0F 84 ? ? ? ? 4C 8B 3B, expected: 1, index: 0
constexpr uintptr_t ScriptBinder_CreateClass = 0x140389AD4 - ImageBase; // 48 8B C4 48 89 58 ? 48 89 70 ? 48 89 78 ? 55 41 56 41 57 48 8D 68 ? 48 81 EC ? ? ? ? 8A 82 ? ? ? ? 48 8B FA, expected: 1, index: 0
constexpr uintptr_t ScriptBinder_CreateProperties = 0x140186C38 - ImageBase; // 48 8B C4 4C 89 40 ? 48 89 50 ? 48 89 48 ? 55 53 56 57 41 54 41 55 41 56 41 57 48 8D A8 ? ? ? ? 48 81 EC ? ? ? ? 4C 8B 7A ? 40 B6 01, expected: 1, index: 0
constexpr uintptr_t ScriptBinder_CreateEnum = 0x140385C70 - ImageBase; // 48 89 5C 24 ? 4C 89 44 24 ? 48 89 4C 24 ? 55 56 57 41 54 41 55 41 56 41 57 48 8B EC 48 81 EC ? ? ? ? 33 FF 4D 8B E8 48 8B F2, expected: 1, index: 0
constexpr uintptr_t ScriptBinder_CreateBitfield = 0x142025584 - ImageBase; // 48 89 5C 24 ? 48 89 74 24 ? 55 57 41 54 41 56 41 57 48 8B EC 48 81 EC ? ? ? ? 33 FF 4D 8B F8 48 8B F2 4C 8B E1, expected: 1, index: 0
constexpr uintptr_t ScriptBinder_CreateFunction = 0x1403875A0 - ImageBase; // 48 8B C4 48 89 58 ? 48 89 70 ? 48 89 78 ? 55 41 54 41 55 41 56 41 57 48 8D 68 ? 48 81 EC ? ? ? ? 44 0F B6 92, expected: 1, index: 0
constexpr uintptr_t ScriptBinder_TranslateBytecode = 0x1401555EC - ImageBase; // 48 89 5C 24 08 48 89 6C 24 10 48 89 74 24 18 57 48 83 EC 20 48 8B 1A 48 8B E9 8B 42 0C, expected: 2, index: 1

constexpr uintptr_t ScriptBundle_ctor = 0x140100A80 - ImageBase; // 40 53 48 83 EC ? 48 8B D9 33 D2 48 89 11 83 C8 ? 48 89 51 ? 48 89 51 ? 48 89 51 ? 89 41 ? 89 51 ? 48 8D 0D ? ? ? ? 48 89 4B, expected: 1, index: 0
constexpr uintptr_t ScriptBundle_dtor = 0x1401005F4 - ImageBase; // 40 53 48 83 EC ? 48 8B D9 E8 ? ? ? ? 48 8D 8B ? ? ? ? FF 15 ? ? ? ? 48 8D 8B ? ? ? ? E8 ? ? ? ? 48 8D 8B, expected: 1, index: 0
constexpr uintptr_t ScriptBundle_Read = 0x1401004B0 - ImageBase; // 48 89 5C 24 ? 48 89 7C 24 ? 55 48 8D 6C 24 ? 48 81 EC ? ? ? ? 33 DB 48 8D 05 ? ? ? ? 48 8B F9 48 89 45 ? 48 8D 0D, expected: 1, index: 0
constexpr uintptr_t ScriptBundle_Validate = 0x140100788 - ImageBase; // 48 8B C4 48 89 58 ? 48 89 70 ? 48 89 48 ? 55 57 41 56 48 8D 68 ? 48 81 EC ? ? ? ? 48 8B 0D ? ? ? ? 4C 8B C2 BE 01, expected: 1, index: 0

constexpr uintptr_t ScriptValidator_Validate = 0x140386DAC - ImageBase; // 48 89 5C 24 ? 48 89 4C 24 ? 55 56 57 41 54 41 55 41 56 41 57 48 8D 6C 24 ? 48 81 EC ? ? ? ? 48 8B C2, expected: 1, index: 0

constexpr uintptr_t StreamingSector_dtor = 0x140459EB4 - ImageBase; // 40 53 48 83 EC ? 48 8D 05 ? ? ? ? 48 8B D9 48 89 01 48 81 C1 C8 00 00 00 E8 ? ? ? ? 48  8D 8B B0 00 00 00 E8 ? ? ? ? 48 8D 8B A0 00 00 00 E8 ? ? ? ? 48 8D 4B 40 E8, expected: 1, index: 0
constexpr uintptr_t StreamingSector_OnReady = 0x1404588C4 - ImageBase; // 48 89 5C 24 ? 48 89 6C 24 ? 48 89 74 24 ? 57 48 83 EC ? 48 8B 91 ? ? ? ? 33 FF 48 8B D9, expected: 1, index: 0

constexpr uintptr_t Transform_ApplyToBox = 0x14030ACE0 - ImageBase; // 48 8B C4 48 81 EC ? ? ? ? 0F 29 70 ? 4C 8B D9 0F 29 78 ? 49 8B C8 44 0F 29 40 ? 4D 8B D0 44 0F 29 48 ? 4C 8B CA, expected: 1, index: 0

constexpr uintptr_t WorldNodeInstance_Initialize = 0x1403A9158 - ImageBase; // 4C 8B DC 49 89 5B ? 49 89 6B ? 49 89 73 ? 57 48 83 EC ? 80 89 ? ? ? ? 01 48 8B DA 0F 10 02 48 8B F1 0F 11 41, expected: 1, index: 0
constexpr uintptr_t WorldNodeInstance_Attach = 0x14038D7E8 - ImageBase; // 40 53 48 83 EC ? 48 8B 01 48 8B D9 80 89 ? ? ? ? ? FF 90 ? ? ? ? 8A 83 ? ? ? ? 24, expected: 1, index: 0
constexpr uintptr_t WorldNodeInstance_Detach = 0x14038CBDC - ImageBase; // 40 53 48 83 EC ? 8A 81 ? ? ? ? 48 8B D9 A8 ? 74 ? 0C ? 88 81 ? ? ? ? 48 8B 01 FF 90, expected: 1, index: 0
constexpr uintptr_t WorldNodeInstance_SetVisibility = 0x141358D6C - ImageBase; // 48 89 5C 24 ? 57 48 83 EC ? 48 8B D9 40 8A FA 48 8B 49 ? 44 8A 83 ? ? ? ? 48 85 C9 0F 84 ? ? ? ? 8A C2 41 80 E0, expected: 1, index: 0
}