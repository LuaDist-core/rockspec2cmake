local load_table = require 'pl.pretty'.load
local Template = require 'pl.text'.Template
local subst = require 'pl.template'.substitute

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


local intro = Template[[
# Generated Cmake file begin
cmake_minimum_required(VERSION 3.1)

project(${package_name} CXX)
]]

local unsupported_platform_check = Template[[
if (${platform})
    message(FATAL_ERROR "Unsupported platform (your platform was explicitly marked as not supported)")
endif()
]]

local supported_platform_check = Template[[
if (${expr})
    message(FATAL_ERROR "Unsupported platform (your platform is not in list of supported platforms)")
endif()
]]


local builtin = [[
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c99 -ggdb3 -O0")

set(SOURCE_FILES mongo-module.c lua-mongoc-client.c lua-mongoc-database.c
lua-mongoc-collection.c lua-bson.c)

add_library(mongo_module SHARED ${SOURCE_FILES} lua-version-compat.h
lua-version-compat.c lua-object-generators.c lua-mongo-cursor.c)

target_link_libraries(${CMAKE_PROJECT_NAME} ${LIBMONGOC_LDFLAGS} ${LIBLUA_LDFLAGS})
set_target_properties (${CMAKE_PROJECT_NAME} PROPERTIES PREFIX "")

]]

if #arg ~= 1 then
    print("Expected one argument...")
else
    local rockspec = load_rockspec(arg[1])

    if not rockspec then
        print("Failed to load rockspec file (" .. arg[1] .. ")")
    else
        print(intro:substitute({package_name = rockspec.package}))

        -- All valid supported_platforms from rockspec file and their cmake counterparts
        local rock2cmake = {
            ["unix"] = "UNIX",
            ["windows"] = "WIN32", -- ?
            ["win32"] = "WIN32",
            ["cygwin"] = "CYGWIN",
            ["macosx"] = "UNIX", -- ?
            ["linux"] = "UNIX", -- ?
            ["freebsd"] = "UNIX" -- ?
        }

        -- Create check for case when we are using unsupported platform
        if rockspec.supported_platforms ~= nil then
            local supported_platforms_check_str = ""
            for _, plat in pairs(rockspec.supported_platforms) do
                local neg, plat = plat:match("^(!?)(.*)")
                if neg == "!" then
                    print(unsupported_platform_check:substitute({platform = rock2cmake[plat]}))
                else
                    if supported_platforms_check_str == "" then
                        supported_platforms_check_str = "NOT " .. rock2cmake[plat]
                    else
                        supported_platforms_check_str = supported_platforms_check_str .. " AND NOT " .. rock2cmake[plat]
                    end
                end
            end

            -- Create check to validate if we are using supported platform
            -- If no positive supported_platforms exists, module is portable to any platform
            if supported_platforms_check_str ~= "" then
                print(supported_platform_check:substitute({expr = supported_platforms_check_str}))
            end
        end

        if rockspec.build.type == "builtin" then
            --[[print(subst(builtin,{
                _escape = ">",
                pairs = pairs,
                ipairs = ipairs,
                package_name = rockspec.package,
                dependencies = rockspec.dependencies,
                ext_dependencies = rockspec.external_dependencies
                })) ]]
        elseif rockspec.build.type == "make" then
            print("message(FATAL_ERROR \"Unhandled rockspec build type\"")
        elseif rockspec.build.type == "cmake" then
            print("message(FATAL_ERROR \"Unhandled rockspec build type\"")
        elseif rockspec.build.type == "command" then
            print("message(FATAL_ERROR \"Unhandled rockspec build type\"")
        elseif rockspec.build.type == "none" then
            print("message(FATAL_ERROR \"Unhandled rockspec build type\"")
        else
            print("message(FATAL_ERROR \"Unhandled rockspec build type\"")
        end
     end
end
