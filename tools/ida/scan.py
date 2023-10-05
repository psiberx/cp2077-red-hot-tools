from cp77ida import Item, Group, Output, scan
from pathlib import Path


# Defines patterns and output files
def patterns():
    return [
        Output(filename="src/Red/Addresses.hpp", namespace="Red::Addresses", groups=[
            Group(functions=[
                Item(name="Main",
                     pattern="40 55 53 48 8D AC 24 ? ? ? ? 48 81 EC ? ? ? ? FF 15 ? ? ? ? E8"),
                Item(name="InvokeSCC",
                     pattern="48 89 5C 24 08 48 89 74 24 10 48 89 7C 24 18 4C 89 74 24 20 55 48 8D AC 24 30 B0 FF FF B8 D0 50 00 00"),
                Item(name='LogChannel',
                     pattern='48 89 5C 24 08 48 89 74 24 18 55 48 8B EC 48 83 EC 70 48 8B 02 48 8D 35 ? ? ? ? 48 83 65 18 00 4C 8D 45 18 48 83 62 30 00 45 33 C9 48 83 62 38 00',
                     expected=2),
            ]),
            Group(name="CBaseEngine", functions=[
                Item(name="LoadScripts",
                     pattern="48 89 5C 24 08 48 89 6C 24 10 48 89 74 24 18 48 89 7C 24 20 41 56 48 83 EC 20 49 8B F9 41 C6 81 A0 02 00 00 01"),
                Item(name="MainLoopTick",
                     pattern="40 56 41 56 48 83 EC 78 48 8B F1 0F 29 7C 24 50 48 8D 4C 24 38 0F 28 F9 E8 ? ? ? ? 48 8D 8C 24 A0 00 00 00"),
            ]),
            Group(name="ISerializable", functions=[
                Item(name="SetReference",
                     pattern="40 53 48 83 EC 30 48 8B 02 48 8B D9 48 89 44 24 20 48 8D 4C 24 20 48 8B 42 08 48 89 44 24 28 E8",
                     expected=24,
                     index=1),
            ]),
            Group(name="JobHandle", functions=[
                Item(name="Wait",
                     pattern="40 53 48 83 EC 30 48 8B D9 33 D2 48 8B 0D ? ? ? ? E8"),
            ]),
            Group(name="ResourceBank", functions=[
                Item(name="ForgetResource",
                     pattern="48 89 5C 24 10 48 89 6C 24 20 56 57 41 54 41 56 41 57 48 83 EC 30 4C 8B F1 49 8B F8"),
            ]),
            Group(name="ResourceDepot", functions=[
                Item(name="LoadArchives",
                     pattern="48 8B C4 4C 89 48 20 55 53 56 41 55 48 8D 68 B1 48 81 EC C8 00 00 00 49 8B 18 4C 8B EA"),
                Item(name="DestructArchives",
                     pattern="85 D2 0F 84 ? ? ? ? 48 89 74 24 10 57 48 83 EC 20 8D 42 FF 48 89 5C 24 30 48 8D 34 80 8B FA"),
                Item(name="RequestResource",
                     pattern="48 89 5C 24 18 48 89 54 24 10 55 56 57 41 54 41 55 41 56 41 57 48 8D 6C 24 D9 48 81 EC B0 00 00 00 33 F6 4C 8B FA"),
            ]),
            Group(name="ScriptBinder", functions=[
                Item(name="ctor",
                     pattern="48 89 5C 24 08 57 48 83 EC 20 48 89 11 48 8B D9 48 C7 41 40 00 00 00 00 49 8B 48 38 48 85 C9"),
                Item(name="Bind",
                     pattern="48 89 5C 24 08 48 89 74 24 10 48 89 7C 24 18 44 88 4C 24 20 55 41 54 41 55 41 56 41 57 48 8B EC"),
                Item(name="ResolveNatives",
                     pattern="48 89 5C 24 08 48 89 6C 24 18 48 89 74 24 20 57 41 54 41 55 41 56 41 57 48 83 EC 20 48 8B 32"),
                Item(name="ResolveTypes",
                     pattern="40 53 57 41 57 48 81 EC 80 00 00 00 48 8B 1A 4C 8B F9 8B 42 0C 48 8D 3C C3 48 3B DF 0F 84"),
                Item(name="CreateClass",
                     pattern="48 89 5C 24 18 48 89 74 24 20 57 41 56 41 57 48 83 EC 50 0F B6 82 89 00 00 00 4C 8B F2 33 DB"),
                Item(name="CreateProperties",
                     pattern="4C 89 44 24 18 48 89 54 24 10 55 53 41 54 41 55 41 56 41 57 48 8D AC 24 18 FF FF FF"),
                Item(name="CreateEnum",
                     pattern="4C 89 44 24 18 48 89 4C 24 08 55 53 56 41 57 48 8B EC 48 83 EC 68 48 83 7A 18 00 48 8D 4D 30",
                     expected=2,
                     index=1),
                Item(name="CreateBitfield",
                     pattern="4C 89 44 24 18 48 89 4C 24 08 55 53 56 41 57 48 8B EC 48 83 EC 68 48 83 7A 18 00 48 8D 4D 30",
                     expected=2),
                Item(name="CreateFunction",
                     pattern="4C 89 44 24 18 48 89 4C 24 08 55 53 56 57 41 54 41 55 41 56 41 57 48 8D 6C 24 E1 48 81 EC 98 00 00 00 44 0F B6 9A 98 00 00 00"),
                Item(name="TranslateBytecode",
                     pattern="40 53 55 56 57 41 54 41 56 41 57 48 83 EC 60 48 8B 1A 48 8B E9 8B 42 0C 4C 8D 24 C3"),
            ]),
            Group(name="ScriptBundle", functions=[
                Item(name="ctor",
                     pattern="48 89 5C 24 10 48 89 74 24 18 57 48 83 EC 20 48 8B F9 48 8D 4C 24 30 E8 ? ? ? ? 33 F6",
                     expected=8),
                Item(name="dtor",
                     pattern="48 89 5C 24 08 48 89 74 24 10 57 48 83 EC 20 48 8B D9 E8 ? ? ? ? 48 8D 8B 38 01 00 00"),
                Item(name="Read",
                     pattern="40 53 48 83 EC 30 48 8B D9 4C 8B C2 48 8B 0D ? ? ? ? 48 8D 54 24 50 41 B9 01 00 00 00 48 8B 01"),
            ]),
            Group(name="ScriptValidator", functions=[
                Item(name="Validate",
                     pattern="48 8B C4 4C 89 40 18 48 89 48 08 55 53 48 8D 68 A1 48 81 EC A8 00 00 00 48 89 70 10 48 8B DA"),
            ]),
        ]),
    ]


# Defines base output dir
def output_dir():
    cwd = Path(__file__).resolve().parent
    return cwd.parent.parent  # 2 levels up


scan(patterns(), output_dir(), __file__)
