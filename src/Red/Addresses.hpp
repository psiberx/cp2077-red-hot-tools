#pragma once

// Generated by cp77ida.py on 2022-11-08 for Cyberpunk 2077 v.1.61
// DO NOT MODIFY. USE tools\ida\scan.py TO GENERATE THIS FILE.

#include <cstdint>

namespace Red::Addresses
{
constexpr uintptr_t ImageBase = 0x140000000;

constexpr uintptr_t Main = 0x1401963B0 - ImageBase; // 40 53 48 81 EC ? ? ? ? FF 15 ? ? ? ? E8 ? ? ? ? E8 ? ? ? ?, expected: 1, index: 0
constexpr uintptr_t InvokeSCC = 0x140A88CE0 - ImageBase; // 48 89 5C 24 08 48 89 74 24 10 48 89 7C 24 18 4C 89 74 24 20 55 48 8D AC 24 30 B0 FF FF B8 D0 50 00 00, expected: 1, index: 0

constexpr uintptr_t CBaseEngine_LoadScripts = 0x140A74C40 - ImageBase; // 48 89 5C 24 08 48 89 6C 24 10 48 89 74 24 18 48 89 7C 24 20 41 56 48 83 EC 20 49 8B F9 41 C6 81 A0 02 00 00 01, expected: 1, index: 0
constexpr uintptr_t CBaseEngine_MainLoopTick = 0x140A75350 - ImageBase; // 40 56 41 56 48 83 EC 78 48 8B F1 0F 29 7C 24 50 48 8D 4C 24 38 0F 28 F9 E8 ? ? ? ? 48 8D 8C 24 A0 00 00 00, expected: 1, index: 0

constexpr uintptr_t ISerializable_SetReference = 0x1401B0180 - ImageBase; // 40 53 48 83 EC 30 48 8B 02 48 8B D9 48 89 44 24 20 48 8D 4C 24 20 48 8B 42 08 48 89 44 24 28 E8, expected: 24, index: 1

constexpr uintptr_t ResourceBank_ForgetResource = 0x14025D040 - ImageBase; // 48 89 5C 24 10 48 89 6C 24 20 56 57 41 54 41 56 41 57 48 83 EC 30 4C 8B F1 49 8B F8, expected: 1, index: 0

constexpr uintptr_t ResourceDepot_LoadArchives = 0x1430105A0 - ImageBase; // 48 8B C4 4C 89 48 20 55 53 56 41 55 48 8D 68 B1 48 81 EC C8 00 00 00 49 8B 18 4C 8B EA, expected: 1, index: 0
constexpr uintptr_t ResourceDepot_DestructArchives = 0x14300FCC0 - ImageBase; // 85 D2 0F 84 ? ? ? ? 48 89 74 24 10 57 48 83 EC 20 8D 42 FF 48 89 5C 24 30 48 8D 34 80 8B FA, expected: 1, index: 0
constexpr uintptr_t ResourceDepot_RequestResource = 0x14300FA00 - ImageBase; // 48 89 5C 24 18 48 89 54 24 10 55 56 57 41 54 41 55 41 56 41 57 48 8D 6C 24 D9 48 81 EC B0 00 00 00 33 F6 4C 8B FA, expected: 1, index: 0

constexpr uintptr_t ScriptBinder_ctor = 0x140278C10 - ImageBase; // 48 89 5C 24 08 57 48 83 EC 20 48 89 11 48 8B D9 48 C7 41 40 00 00 00 00 49 8B 48 38 48 85 C9, expected: 1, index: 0
constexpr uintptr_t ScriptBinder_Bind = 0x140278D50 - ImageBase; // 48 89 5C 24 08 48 89 74 24 10 48 89 7C 24 18 44 88 4C 24 20 55 41 54 41 55 41 56 41 57 48 8B EC, expected: 1, index: 0
constexpr uintptr_t ScriptBinder_ResolveNatives = 0x14027BB10 - ImageBase; // 48 89 5C 24 08 48 89 6C 24 18 48 89 74 24 20 57 41 54 41 55 41 56 41 57 48 83 EC 20 48 8B 32, expected: 1, index: 0
constexpr uintptr_t ScriptBinder_ResolveTypes = 0x14027BD20 - ImageBase; // 40 53 57 41 57 48 81 EC 80 00 00 00 48 8B 1A 4C 8B F9 8B 42 0C 48 8D 3C C3 48 3B DF 0F 84, expected: 1, index: 0
constexpr uintptr_t ScriptBinder_CreateClass = 0x140279320 - ImageBase; // 48 89 5C 24 18 48 89 74 24 20 57 41 56 41 57 48 83 EC 50 0F B6 82 89 00 00 00 4C 8B F2 33 DB, expected: 1, index: 0
constexpr uintptr_t ScriptBinder_CreateProperties = 0x140279590 - ImageBase; // 4C 89 44 24 18 48 89 54 24 10 55 53 41 54 41 55 41 56 41 57 48 8D AC 24 18 FF FF FF, expected: 1, index: 0
constexpr uintptr_t ScriptBinder_CreateEnum = 0x14027A3A0 - ImageBase; // 4C 89 44 24 18 48 89 4C 24 08 55 53 56 41 57 48 8B EC 48 83 EC 68 48 83 7A 18 00 48 8D 4D 30, expected: 2, index: 1
constexpr uintptr_t ScriptBinder_CreateBitfield = 0x1402790F0 - ImageBase; // 4C 89 44 24 18 48 89 4C 24 08 55 53 56 41 57 48 8B EC 48 83 EC 68 48 83 7A 18 00 48 8D 4D 30, expected: 2, index: 0
constexpr uintptr_t ScriptBinder_CreateFunction = 0x14027A5D0 - ImageBase; // 4C 89 44 24 18 48 89 4C 24 08 55 53 56 57 41 54 41 55 41 56 41 57 48 8D 6C 24 E1 48 81 EC 98 00 00 00 44 0F B6 9A 98 00 00 00, expected: 1, index: 0
constexpr uintptr_t ScriptBinder_TranslateBytecode = 0x14027B0D0 - ImageBase; // 4C 8B DC 55 53 57 41 55 49 8D 6B A1 48 81 EC 98 00 00 00 48 8B 1A 4C 8B E9 8B 42 0C 48 8D 3C C3, expected: 1, index: 0

constexpr uintptr_t ScriptBundle_ctor = 0x1402740B0 - ImageBase; // 48 89 5C 24 10 48 89 74 24 18 57 48 83 EC 20 48 8B F9 48 8D 4C 24 30 E8 ? ? ? ? 33 F6, expected: 8, index: 0
constexpr uintptr_t ScriptBundle_dtor = 0x140274300 - ImageBase; // 48 89 5C 24 08 48 89 74 24 10 57 48 83 EC 20 48 8B D9 E8 ? ? ? ? 48 8D 8B 38 01 00 00, expected: 1, index: 0
constexpr uintptr_t ScriptBundle_Read = 0x1402763F0 - ImageBase; // 40 53 48 83 EC 30 48 8B D9 4C 8B C2 48 8B 0D ? ? ? ? 48 8D 54 24 50 41 B9 01 00 00 00 48 8B 01, expected: 1, index: 0

constexpr uintptr_t ScriptValidator_Validate = 0x1402774E0 - ImageBase; // 48 8B C4 4C 89 40 18 48 89 48 08 55 53 48 8D 68 A1 48 81 EC A8 00 00 00 48 89 70 10 48 8B DA, expected: 1, index: 0
}
