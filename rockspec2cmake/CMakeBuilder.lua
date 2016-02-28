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





local function table_concat(tbl)
    return table.concat(tbl, " ")
end

CMakeBuilder = {}

function CMakeBuilder:new(o, package_name)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    
    self.supported_platforms = {}
    self.unsupported_platforms = {}
    self.cxx_modules = {}
    
    self.package_name = package_name
    return o
end

function CMakeBuilder:add_unsupported_platform(platform)
    table.insert(self.unsupported_platforms, platform)
end

function CMakeBuilder:add_supported_platform(platform)
    table.insert(self.supported_platforms, platform)
end

function CMakeBuilder:add_cxx_module()
    
end

function CMakeBuilder:generate()
    local res = ""
    
    res = res .. intro:substitute({package_name = self.package_name})
    
    -- Unsupported platforms
    for _, plat in pairs(self.unsupported_platforms) do
        res = res .. unsupported_platform_check:substitute({platform = rock2cmake[plat]})
    end

    -- Supported platforms    
    if #self.supported_platforms ~= 0 then
        local supported_platforms_check_str = ""
        for _, plat in pairs(self.supported_platforms) do
            if supported_platforms_check_str == "" then
                supported_platforms_check_str = "NOT " .. rock2cmake[plat]
            else
                supported_platforms_check_str = supported_platforms_check_str .. " AND NOT " .. rock2cmake[plat]
            end
        end
        
        res = res .. supported_platform_check:substitute({expr = supported_platforms_check_str})
    end

    return res
end

return CMakeBuilder
