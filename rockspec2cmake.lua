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

-- Move to CMakeBuilder
local function table_concat(tbl)
    return table.concat(tbl, " ")
end

local function install_lua_file(cmake, name, path)
    -- print("Install lua file " .. name .. " - " .. path)
    
    -- Force install file as name.lua, rename if needed
end

local function add_cxx_module(cmake, module_info)
    local libraries = ""
    if module_info.libraries ~= nil then
        local libdirs = table_concat(module_info.libdirs)
        for _, lib in pairs(module_info.libraries) do
            libraries = libraries .. find_libraries:substitute({ lib = lib, path = libdirs })
        end
    end
    
    print(cxx_module:substitute({ incdirs = table_concat(module_info.incdirs), name = module_info.name,
        sources = table_concat(module_info.sources), find_libraries = libraries, libraries = table_concat(module_info.libraries),
        defines = table_concat(module_info.defines) }))
end

local function process_builtin(cmake, rockspec)
    -- Process per-platform overrides
    if rockspec.build.platforms ~= nil then
        for _, platform in ipairs(rockspec.build.platforms) do
            -- foo
        end
    end
    
    for name, info in pairs(rockspec.build.modules) do
        if type(info) == "string" then
            -- Pathname of Lua file or C source, for modules based on single source file
            local ext = info:match(".([^.]+)$")
            if ext == "lua" then
                install_lua_file(cmake, name, info)
            else
                add_cxx_module(cmake, { name = name, sources = { info } })
            end
        elseif type(info) == "table" then
            -- Two options:
            -- array of strings - pathnames of C sources
            -- table - possible fields sources, libraries, defines, incdirs, libdirs
            if type(info.sources) == "string" then
                info.sources = { info.sources }
            end
            
            add_cxx_module(cmake, { name = name, sources  = info.sources, libraries = info.libraries, 
                defines = info.defines, incdirs = info.incdirs, libdirs = info.libdirs })
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
            print("message(FATAL_ERROR \"Rockspec build type is cmake, please use the attached one\")")
        else
            print("message(FATAL_ERROR \"Unhandled rockspec build type\")")
        end

        print(cmake:generate())
     end
end
