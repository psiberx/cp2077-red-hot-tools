set_xmakever("2.5.9")

set_project("RedHotTools")
set_version("1.1.6", {build = "%y%m%d%H%M"})

set_arch("x64")
set_languages("cxx2a")
add_cxxflags("/MP /GR- /EHsc")

if is_mode("debug") then
    set_symbols("debug")
    set_optimize("none")
    add_cxxflags("/Od /Ob0 /Zi /RTC1")
elseif is_mode("release") then
    set_symbols("hidden")
    set_strip("all")
    set_optimize("fastest")
    add_cxxflags("/Ob2")
elseif is_mode("releasedbg") then
    set_symbols("debug")
    set_strip("all")
    set_optimize("fastest")
    add_cxxflags("/Ob1 /Zi")
end

if is_mode("debug") then
    set_runtimes("MDd")
else
    set_runtimes("MD")
end

add_requires("fmt", "hopscotch-map", "minhook", "spdlog", "tiltedcore")

target("RedHotTools")
    set_default(true)
    set_kind("shared")
    set_filename("RedHotTools.dll")
    set_pcxxheader("src/pch.hpp")
    add_files("src/**.cpp", "src/**.rc", "lib/**.cpp")
    add_headerfiles("src/**.hpp", "lib/**.hpp", "vendor/filewatch/**.hpp")
    add_includedirs("src/", "lib/", "vendor/filewatch/")
    add_deps("RED4ext.SDK", "nameof", "semver", "wil")
    add_packages("fmt", "hopscotch-map", "minhook", "spdlog", "tiltedcore")
    add_syslinks("Version", "User32")
    add_defines("WINVER=0x0601", "WIN32_LEAN_AND_MEAN", "NOMINMAX", "_DISABLE_EXTENDED_ALIGNED_STORAGE")
    set_configdir(".")
    add_configfiles("config/Project.hpp.in", {prefixdir = "src/App"})
    add_configfiles("config/Version.rc.in", {prefixdir = "src/App"})
    add_configfiles("config/version.lua.in", {prefixdir = "support/cet"})
    set_configvar("AUTHOR", "psiberx")
    set_configvar("NAME", "RedHotTools")

target("RED4ext.SDK")
    set_default(false)
    set_kind("static")
    set_group("vendor")
    add_headerfiles("vendor/RED4ext.SDK/include/**.hpp")
    add_includedirs("vendor/RED4ext.SDK/include/", { public = true })

target("nameof")
    set_default(false)
    set_kind("static")
    set_group("vendor")
    add_headerfiles("vendor/nameof/include/**.hpp")
    add_includedirs("vendor/nameof/include/", { public = true })

target("semver")
    set_default(false)
    set_kind("static")
    set_group("vendor")
    add_headerfiles("vendor/semver/include/**.hpp")
    add_includedirs("vendor/semver/include/", { public = true })

target("wil")
    set_default(false)
    set_kind("static")
    set_group("vendor")
    add_headerfiles("vendor/wil/include/**.h")
    add_includedirs("vendor/wil/include/", { public = true })

add_rules("plugin.vsxmake.autoupdate")
