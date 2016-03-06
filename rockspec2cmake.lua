local load_table = require 'pl.pretty'.load
local Template = require 'pl.text'.Template
local subst = require 'pl.template'.substitute
local CMakeBuilder = require 'rockspec2cmake.CMakeBuilder'

module("rockspec2cmake", package.seeall)

local function load_rockspec(filename, env)
    local fd, err = io.open(filename)
    if not fd then
        return nil
    end
    local str, err = fd:read("*all")
    fd:close()
    if not str then
        return nil
    end
    -- str = str:gsub("^#![^\n]*\n", "")
    return load_table(str)
end

-- Concatenates string values from table into single space separated string
-- If argument is nil, returns empty string
-- If arguments is string itself, returns it
local function table_concat(tbl)
    if type(tbl) == "string" then
        return tbl
    end

    res = ""
    for _, v in pairs(tbl or {}) do
        if res == "" then
            res = v
        else
            res = res .. " " .. v
        end
    end

    return res
end

-- For all entries in build table which are not present in override table, create their counterparts
-- Except for table "platforms"
local function fill_platform_override(override, build, recursive)
    for k, v in pairs(build) do
        if recursive ~= nil or k ~= "platforms" then
            -- Recursively merge tables
            if type(v) == "table" and type(override[k] or false) == "table" then
                fill_platform_override(override[k], build[k], true)
            -- Don't override value with table
            elseif override[k] == nil then
                override[k] = v
            end
        end
    end
end

local process_builtin

local function process_install(cmake, install, platform)
    for what, files in pairs(install) do
        cmake:set_cmake_variable("BUILD_INSTALL_" .. what, table_concat(value), platform)
    end
end

local function process_module(cmake, name, info, platform)
    -- Pathname of Lua file or C source, for modules based on single source file
    if type(info) == "string" then
        local ext = info:match(".([^.]+)$")
        if ext == "lua" then
            cmake:add_lua_module(name, platform)
        else
            cmake:add_cxx_target(name, platform)
        end

        cmake:set_cmake_variable(name .. "_SOURCES", info, platform)
    -- Two options:
    -- array of strings - pathnames of C sources
    -- table - possible fields sources, libraries, defines, incdirs, libdirs
    elseif type(info) == "table" then
        cmake:add_cxx_target(name, platform)
        cmake:set_cmake_variable(name .. "_SOURCES", table_concat(info.sources), platform)
        cmake:set_cmake_variable(name .. "_LIBRARIES", table_concat(info.libraries), platform)
        cmake:set_cmake_variable(name .. "_DEFINES", table_concat(info.defines), platform)
        cmake:set_cmake_variable(name .. "_INCDIRS", table_concat(info.incdirs), platform)
        cmake:set_cmake_variable(name .. "_LIBDIRS", table_concat(info.libdirs), platform)
    end
end

local function process_modules(cmake, modules, platform)
    for name, info in pairs(modules) do
        process_module(cmake, name, info, platform)
    end
end

local function process_platform_overrides(cmake, platforms)
    for platform, build in pairs(platforms) do
        process_builtin(cmake, build, platform)
    end
end

process_builtin = function(cmake, build, platform)
    for key, value in pairs(build) do
        if key == "install" then
            process_install(cmake, value, platform)
        elseif key == "copy_directories" then
            cmake:set_cmake_variable("BUILD_COPY_DIRECTORIES", table_concat(value), platform)
        elseif key == "modules" then
            process_modules(cmake, value, platform)
        elseif key == "platforms" then
            assert(platform == nil)
            process_platform_overrides(cmake, value)
        end
    end
end

if #arg ~= 1 then
    print("Expected one argument...")
else
    local rockspec = load_rockspec(arg[1])

    if not rockspec then
        print("Failed to load rockspec file (" .. arg[1] .. ")")
    else
        local cmake = CMakeBuilder:new(nil, rockspec.package)

        -- Create check for case when we are using unsupported platform
        if rockspec.supported_platforms ~= nil then
            local supported_platforms_check_str = ""
            for _, plat in pairs(rockspec.supported_platforms) do
                local neg, plat = plat:match("^(!?)(.*)")
                if neg == "!" then
                    cmake:add_unsupported_platform(plat)
                else
                    cmake:add_supported_platform(plat)
                end
            end
        end

        if rockspec.build.type == "builtin" then
            process_builtin(cmake, rockspec.build)
        elseif rockspec.build.type == "cmake" then
            cmake:fatal_error("Rockspec build type is cmake, please use the attached one")
        else
            cmake:fatal_error("Unhandled rockspec build type")
        end

        print(cmake:generate())
     end
end
