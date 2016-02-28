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

local function prepare_build_table(build)
    local res = {}

    -- Copy equivalent fields
    if build.install ~= nil then
        res.install = {}
        res.install.lua = build.install.lua
        res.install.lib = build.install.lib
        res.install.conf = build.install.conf
        res.install.bin = build.install.bin
    end

    res.copy_directories = build.copy_directories

    -- Divide modules into two different tables (cxx and lua)
    res.lua_modules = {}
    res.cxx_modules = {}
    for name, info in pairs(build.modules) do
        -- Pathname of Lua file or C source, for modules based on single source file
        if type(info) == "string" then
            local ext = info:match(".([^.]+)$")
            if ext == "lua" then
                res.lua_modules[name] = info
            else
                res.cxx_modules[name] = {sources = {info}}
            end
        -- Two options:
        -- array of strings - pathnames of C sources
        -- table - possible fields sources, libraries, defines, incdirs, libdirs
        elseif type(info) == "table" then
            if type(info.sources) == "string" then
                info.sources = { info.sources }
            end

            res.cxx_modules[name] = {sources = info.sources, libraries = info.libraries,
                defines = info.defines, incdirs = info.incdirs, libdirs = info.libdirs}
        end
    end

    return res
end

local function process_builtin(cmake, rockspec)
    cmake:add_builtin_configuration(prepare_build_table(rockspec.build))

    -- Process per-platform overrides
    if rockspec.build.platforms ~= nil then
        for platform, build in pairs(rockspec.build.platforms) do
            -- For each platform override, merge it with rockspec.build
            fill_platform_override(build, rockspec.build)
            cmake:add_builtin_configuration(prepare_build_table(build), platform)
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
            process_builtin(cmake, rockspec)
        elseif rockspec.build.type == "cmake" then
            cmake:fatal_error("Rockspec build type is cmake, please use the attached one")
        else
            cmake:fatal_error("Unhandled rockspec build type")
        end

        print(cmake:generate())
     end
end
