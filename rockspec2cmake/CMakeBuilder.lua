local Template = require 'pl.text'.Template
local subst = require 'pl.template'.substitute

module("rockspec2cmake", package.seeall)

-- All valid supported_platforms from rockspec file and their cmake counterparts
local rock2cmake_platform = {
    ["unix"] = "UNIX",
    ["windows"] = "WIN32", -- ?
    ["win32"] = "WIN32",
    ["cygwin"] = "CYGWIN",
    ["macosx"] = "UNIX", -- ?
    ["linux"] = "UNIX", -- ?
    ["freebsd"] = "UNIX" -- ?
}

local intro = Template[[
# Generated Cmake file begin
cmake_minimum_required(VERSION 3.1)

project(${package_name} C CXX)

]]

local fatal_error = Template[[
message(FATAL_ERROR "${message}")

]]

local unsupported_platform_check = Template [[
if (${platform})
    message(FATAL_ERROR "Unsupported platform (your platform was explicitly marked as not supported)")
endif()

]]

local supported_platform_check = Template [[
if (${expr})
    message(FATAL_ERROR "Unsupported platform (your platform is not in list of supported platforms)")
endif()

]]

local cxx_module = Template [[
include_directories(${incdirs})

add_library(${name} MODULE ${sources})

${find_libraries}
target_link_libraries(${name} ${libraries})

add_definitions(${defines})
]]

local find_libraries = Template [[
find_library(${lib} ${lib} ${path})
]]

local platform_override_intro = Template[[
if (${platform})
    set(PLATFORM_OVERRIDE_EXECUTED true)

]]

local platform_not_overriden_intro = Template[[
if (NOT PLATFORM_OVERRIDE_EXECUTED)
]]



local function table_concat(tbl)
    return table.concat(tbl, " ")
end

local function generate_builtin(build)
    local res = ""

    -- install.{lua|lib|conf|bin}

    -- copy_directories

    -- lua_modules
        -- print("Install lua file " .. name .. " - " .. path)
    -- Force install file as name.lua, rename if needed

    -- cxx_modules
    for name, data in pairs(build.cxx_modules or {}) do
        local libraries = ""
        local libdirs = table_concat(data.libdirs)
        for _, lib in pairs(data.libraries or {}) do
            libraries = libraries .. find_libraries:substitute({ lib = lib, path = libdirs })
        end

        res = res .. cxx_module:substitute({incdirs = table_concat(data.incdirs), name = name,
            sources = table_concat(data.sources), find_libraries = libraries, libraries = table_concat(data.libraries),
            defines = table_concat(data.defines)})
    end

    -- Ident each line in result
    local ident = "    "
    res = ident .. res
    res = res:gsub("\n", "\n" .. ident)
    res = res:gsub(ident .. "$", "")
    return res
end

-- CMakeBuilder
CMakeBuilder = {}

function CMakeBuilder:new(o, package_name)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- Tables with string values
    self.errors = {}
    self.supported_platforms = {}
    self.unsupported_platforms = {}

    -- Table which contains preprocessed rockspec "build" table, entries
    -- install.{lua|lib|conf|bin} - as in rockspec
    -- copy_directories - as in rockspec
    -- lua_modules - table with module name as key and string value (path to .lua source)
    -- cxx_modules - table with module name as key and table values as in rockspec
    --                       (sources, libraries, defines, incdirs, libdirs)
    self.builtin = {}
    -- Table where key is representing LuaRocks platform string and value is table as described
    -- in self.builtin
    self.per_platform_builtin = {}

    self.package_name = package_name
    return o
end

function CMakeBuilder:fatal_error(platform)
    table.insert(self.errors, platform)
end

function CMakeBuilder:add_unsupported_platform(platform)
    table.insert(self.unsupported_platforms, platform)
end

function CMakeBuilder:add_supported_platform(platform)
    table.insert(self.supported_platforms, platform)
end

function CMakeBuilder:add_builtin_configuration(data, platform)
    if platform ~= nil then
        self.per_platform_builtin[platform] = data
    else
        self.builtin = data
    end
end

function CMakeBuilder:generate()
    local res = ""

    res = res .. intro:substitute({package_name = self.package_name})

    -- Print all fatal errors at the beginning
    for _, error_msg in pairs(self.errors) do
        res = res .. fatal_error:substitute({message = error_msg})
    end

    -- Unsupported platforms
    for _, plat in pairs(self.unsupported_platforms) do
        res = res .. unsupported_platform_check:substitute({platform = rock2cmake_platform[plat]})
    end

    -- Supported platforms
    if #self.supported_platforms ~= 0 then
        local supported_platforms_check_str = ""
        for _, plat in pairs(self.supported_platforms) do
            if supported_platforms_check_str == "" then
                supported_platforms_check_str = "NOT " .. rock2cmake_platform[plat]
            else
                supported_platforms_check_str = supported_platforms_check_str .. " AND NOT " .. rock2cmake_platform[plat]
            end
        end

        res = res .. supported_platform_check:substitute({expr = supported_platforms_check_str})
    end

    -- Platform overrides if present
    for platform, build in pairs(self.per_platform_builtin or {}) do
        res = res .. platform_override_intro:substitute({platform = rock2cmake_platform[platform]})
        res = res .. generate_builtin(build)
        res = res .. "endif()\n\n"
    end

    res = res .. platform_not_overriden_intro:substitute({})
    res = res .. generate_builtin(self.builtin)
    res = res .. "endif()\n"

    return res
end

return CMakeBuilder
