#pragma once

#include <algorithm>
#include <concepts>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <functional>
#include <future>
#include <map>
#include <memory>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>
#include <vector>

#include <RED4ext/Api/EMainReason.hpp>
#include <RED4ext/Api/Sdk.hpp>
#include <RED4ext/Api/Runtime.hpp>
#include <RED4ext/Api/SemVer.hpp>
#include <RED4ext/Api/Version.hpp>

#include <RED4ext/CName.hpp>
#include <RED4ext/CString.hpp>
#include <RED4ext/Common.hpp>
#include <RED4ext/DynArray.hpp>
#include <RED4ext/GameApplication.hpp>
#include <RED4ext/GameEngine.hpp>
#include <RED4ext/Handle.hpp>
#include <RED4ext/HashMap.hpp>
#include <RED4ext/ISerializable.hpp>
#include <RED4ext/NativeTypes.hpp>
#include <RED4ext/Relocation.hpp>
#include <RED4ext/ResourceDepot.hpp>
#include <RED4ext/ResourceLoader.hpp>
#include <RED4ext/ResourcePath.hpp>
#include <RED4ext/RTTISystem.hpp>
#include <RED4ext/RTTITypes.hpp>
#include <RED4ext/SortedArray.hpp>
#include <RED4ext/Memory/Allocators.hpp>
#include <RED4ext/Memory/SharedPtr.hpp>
#include <RED4ext/Scripting/CProperty.hpp>
#include <RED4ext/Scripting/Functions.hpp>
#include <RED4ext/Scripting/IScriptable.hpp>
#include <RED4ext/Scripting/Stack.hpp>

#include <FileWatch.hpp>

#include "Core/Raw.hpp"
#include "Core/Stl.hpp"

#include "Red/Alias.hpp"
#include "Red/Stl.hpp"

#ifdef VERBOSE
#include "Red/Log.hpp"
#endif
