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
                     pattern="48 8B C4 48 89 58 ? 48 89 70 ? 48 89 78 ? 55 41 56 41 57 48 8D A8 ? ? ? ? B8 ? ? ? ? E8 ? ? ? ? 48 2B E0 41 8A D8 4C 8B F2"),
                Item(name='LogChannel',
                     pattern='48 89 5C 24 08 48 89 74 24 18 55 48 8B EC 48 83 EC 70 48 8B 02 48 8D 35 ? ? ? ? 48 83 65 18 00 4C 8D 45 18 48 83 62 30 00 45 33 C9 48 83 62 38 00',
                     expected=2),
            ]),
            Group(name="CBaseEngine", functions=[
                Item(name="LoadScripts",
                     pattern="48 89 5C 24 ? 48 89 6C 24 ? 48 89 74 24 ? 57 41 56 41 57 48 83 EC ? 49 8D 99"),
                Item(name="MainLoopTick",
                     pattern="48 8B C4 55 53 56 57 41 54 41 56 41 57 48 8D 68 ? 48 81 EC ? ? ? ? 0F 29 70 ? 48 8B F9 0F 29 78 ? 48 8D 4D"),
            ]),
            Group(name='FileSystem', pointers=[
                Item(name="Instance",
                     pattern='48 89 05 ? ? ? ? 48 83 C4 ? 5F C3',
                     offset=3,
                     expected=6,
                     index=2),
            ], functions=[
                Item(name="Close",
                     pattern="48 89 5C 24 ? 57 48 83 EC ? 48 8B 39 48 85 FF 74 ? 48 8B 07 48 8B CF FF 10 4C 8B  07 33 D2 48 8B CF 48 8B D8 41 FF 50 08"),
            ]),
            Group(name="ISerializable", functions=[
                Item(name="SetReference",
                     pattern="40 53 48 83 EC ? 4C 8B 42 ? 48 8B D9 48 8B 0A 4D 85 C0 74 ? F0 41 FF 40 ? 48 8B 43 ? 48 89 44 24 ? 48 8B 03 48 89 0B 48"),
            ]),
            Group(name="JobHandle", functions=[
                Item(name="Wait",
                     pattern="48 8B 11 41 83 C9 FF 48 8B 0D ? ? ? ? 45 33 C0 E9"),
            ]),
            Group(name="ResourceBank", functions=[
                Item(name="ForgetResource",
                     pattern="48 8B C4 48 89 58 ? 48 89 70 ? 4C 89 40 ? 55 57 41 56 48 8D 68 ? 48 81 EC ? ? ? ? 48 8D 99 ? ? ? ? 4C 8B F1"),
            ]),
            Group(name="ResourceDepot", functions=[
                Item(name="LoadArchives",
                     pattern="4C 89 4C 24 ? 48 89 4C 24 ? 55 53 56 57 41 55 41 56 41 57 48 8D 6C 24 ? 48 81 EC ? ? ? ? 45 8B 78 ?"),
                Item(name="DestructArchives",
                     pattern="85 D2 74 ? 48 89 5C 24 ? 57 48 83 EC ? 8D 42 ? 8B DA 48 8D 3C 80 48 C1 E7 ? 48 03 F9 48 8B CF 48 83 EF ? E8 ? ? ? ? 83 C3 ? 75", # ? 48 8B 5C 24 ? 48 83 C4
                     expected=22,
                     index=2),
                Item(name="RequestResource",
                     pattern="4C 89 4C 24 ? 48 89 54 24 ? 55 53 56 57 41 54 41 55 41 56 41 57 48 8D 6C 24 ? 48 81 EC ? ? ? ? 48 8D B1"),
            ]),
            Group(name="ScriptBinder", functions=[
                Item(name="ResolveNatives",
                     pattern="48 89 5C 24 ? 55 56 57 41 54 41 55 41 56 41 57 48 8B EC 48 83 EC ? 48 8B 3A 4D 8B F8 8B 42 ? 4C 8B E1 48 8D 04 C7 48 89 45"),
                Item(name="ResolveTypes",
                     pattern="40 53 55 56 57 41 54 41 56 41 57 48 83 EC ? 48 8B 1A 48 8B E9 8B 42 ? 4C 8D 24 C3 49 3B DC 0F 84 ? ? ? ? 4C 8B 3B"),
                Item(name="CreateClass",
                     pattern="48 8B C4 48 89 58 ? 48 89 70 ? 48 89 78 ? 55 41 56 41 57 48 8D 68 ? 48 81 EC ? ? ? ? 8A 82 ? ? ? ? 48 8B FA"),
                Item(name="CreateProperties",
                     pattern="48 8B C4 4C 89 40 ? 48 89 50 ? 48 89 48 ? 55 53 56 57 41 54 41 55 41 56 41 57 48 8D A8 ? ? ? ? 48 81 EC ? ? ? ? 4C 8B 7A ? 40 B6 01"),
                Item(name="CreateEnum",
                     pattern="48 89 5C 24 ? 4C 89 44 24 ? 48 89 4C 24 ? 55 56 57 41 54 41 55 41 56 41 57 48 8B EC 48 81 EC ? ? ? ? 33 FF 4D 8B E8 48 8B F2"),
                Item(name="CreateBitfield",
                     pattern="48 89 5C 24 ? 48 89 74 24 ? 55 57 41 54 41 56 41 57 48 8B EC 48 81 EC ? ? ? ? 33 FF 4D 8B F8 48 8B F2 4C 8B E1"),
                Item(name="CreateFunction",
                     pattern="48 8B C4 48 89 58 ? 48 89 70 ? 48 89 78 ? 55 41 54 41 55 41 56 41 57 48 8D 68 ? 48 81 EC ? ? ? ? 44 0F B6 92"),
                Item(name="TranslateBytecode",
                     pattern="48 89 5C 24 08 48 89 6C 24 10 48 89 74 24 18 57 48 83 EC 20 48 8B 1A 48 8B E9 8B 42 0C",
                     expected=2),
            ]),
            Group(name="ScriptBundle", functions=[
                Item(name="ctor",
                     pattern="40 53 48 83 EC ? 48 8B D9 33 D2 48 89 11 83 C8 ? 48 89 51 ? 48 89 51 ? 48 89 51 ? 89 41 ? 89 51 ? 48 8D 0D ? ? ? ? 48 89 4B"),
                Item(name="dtor",
                     pattern="40 53 48 83 EC ? 48 8B D9 E8 ? ? ? ? 48 8D 8B ? ? ? ? FF 15 ? ? ? ? 48 8D 8B ? ? ? ? E8 ? ? ? ? 48 8D 8B"),
                Item(name="Read",
                     pattern="48 89 5C 24 ? 48 89 7C 24 ? 55 48 8D 6C 24 ? 48 81 EC ? ? ? ? 33 DB 48 8D 05 ? ? ? ? 48 8B F9 48 89 45 ? 48 8D 0D"),
                Item(name="Validate",
                     pattern="48 8B C4 48 89 58 ? 48 89 70 ? 48 89 48 ? 55 57 41 56 48 8D 68 ? 48 81 EC ? ? ? ? 48 8B 0D ? ? ? ? 4C 8B C2 BE 01"),
            ]),
            Group(name="ScriptValidator", functions=[
                Item(name="Validate",
                     pattern="48 89 5C 24 ? 48 89 4C 24 ? 55 56 57 41 54 41 55 41 56 41 57 48 8D 6C 24 ? 48 81 EC ? ? ? ? 48 8B C2"),
            ]),
        ]),
    ]


# Defines base output dir
def output_dir():
    cwd = Path(__file__).resolve().parent
    return cwd.parent.parent  # 2 levels up


scan(patterns(), output_dir(), __file__)
