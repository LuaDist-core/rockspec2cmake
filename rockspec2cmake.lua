local load_table = require 'pl.pretty'.load
local Template = require 'pl.text'.Template
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
-- If value to be concatenaded is in form of rockspec variable $(var),
-- this function converts it to cmake variable ${var}
local function table_concat(tbl)
    local function try_convert_var(str)
        if str:match("^%$%(.*%)$") then
            return str:gsub("%(", "{"):gsub("%)", "}")
        end

        return str
    end

    if type(tbl) == "string" then
        return tbl
    end

    res = ""
    for _, v in pairs(tbl or {}) do
        if res == "" then
            res = try_convert_var(v)
        else
            res = res .. " " .. try_convert_var(v)
        end
    end

    return res
end

local function is_string_array(tbl)
    for k, v in pairs(tbl) do
        if type(k) ~= "number" or type(v) ~= "string" then
            return nil
        end
    end

    return true
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

        if is_string_array(info) then
            cmake:set_cmake_variable(name .. "_SOURCES", table_concat(info), platform)
        else
            cmake:set_cmake_variable(name .. "_SOURCES", table_concat(info.sources), platform)
            cmake:set_cmake_variable(name .. "_LIB_NAMES", table_concat(info.libraries), platform)
            cmake:set_cmake_variable(name .. "_DEFINES", table_concat(info.defines), platform)
            cmake:set_cmake_variable(name .. "_INCDIRS", table_concat(info.incdirs), platform)
            cmake:set_cmake_variable(name .. "_LIBDIRS", table_concat(info.libdirs), platform)
        end
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

local function process_ext_dep(cmake, ext_dep, platform)
    for key, value in pairs(ext_dep) do
        if key == "platforms" then
            assert(platform == nil)
            for platform, ext_dep2 in pairs(value) do
                process_ext_dep(cmake, ext_dep2, platform)
            end
        else
            cmake:add_ext_dep(key, platform)
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

        -- Parse (un)supported platforms
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

        -- Parse external dependencies
        if rockspec.external_dependencies ~= nil then
            process_ext_dep(cmake, rockspec.external_dependencies)
        end

        -- Parse build rules
        if rockspec.build == nil then
            cmake:fatal_error("Rockspec does not contain build information")
        elseif rockspec.build.type == "builtin" then
            process_builtin(cmake, rockspec.build)
        elseif rockspec.build.type == "cmake" then
            cmake:fatal_error("Rockspec build type is cmake, please use the attached one")
        else
            cmake:fatal_error("Unhandled rockspec build type")
        end

        print(cmake:generate())
     end
end
