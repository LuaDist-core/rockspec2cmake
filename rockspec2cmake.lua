local subst = require 'pl.template'.substitute


-- luarocks/persist.lua

--- Load and run a Lua file in an environment.
-- @param filename string: the name of the file.
-- @param env table: the environment table.
-- @return (true, any) or (nil, string, string): true and the return value
-- of the file, or nil, an error message and an error code ("open", "load"
-- or "run") in case of errors.
local function run_file(filename, env)
   local fd, err = io.open(filename)
   if not fd then
      return nil, err, "open"
   end
   local str, err = fd:read("*a")
   fd:close()
   if not str then
      return nil, err, "open"
   end
   str = str:gsub("^#![^\n]*\n", "")
   local chunk, ran
   if _VERSION == "Lua 5.1" then -- Lua 5.1
      chunk, err = loadstring(str, filename)
      if chunk then
         setfenv(chunk, env)
         ran, err = pcall(chunk)
      end
   else -- Lua 5.2
      chunk, err = load(str, filename, "t", env)
      if chunk then
         ran, err = pcall(chunk)
      end
   end
   if not chunk then
      return nil, "Error loading file: "..err, "load"
   end
   if not ran then
      return nil, "Error running file: "..err, "run"
   end
   return true, err
end

--- Load a Lua file containing assignments, storing them in a table.
-- The global environment is not propagated to the loaded file.
-- @param filename string: the name of the file.
-- @param tbl table or nil: if given, this table is used to store
-- loaded values.
-- @return (table, table) or (nil, string, string): a table with the file's assignments
-- as fields and set of undefined globals accessed in file,
-- or nil, an error message and an error code ("open"; couldn't open the file,
-- "load"; compile-time error, or "run"; run-time error)
-- in case of errors.
function load_into_table(filename, tbl)
   assert(type(filename) == "string")
   assert(type(tbl) == "table" or not tbl)

   local result = tbl or {}
   local globals = {}
   local globals_mt = {
      __index = function(t, k)
         globals[k] = true
      end
   }
   local save_mt = getmetatable(result)
   setmetatable(result, globals_mt)
   
   local ok, err, errcode = run_file(filename, result)
   
   setmetatable(result, save_mt)

   if not ok then
      return nil, err, errcode
   end
   return result, globals
end




local intro = [[
cmake_minimum_required(VERSION 3.1)

project($(rockspec.package_name) CXX)
include(cmake/dist.cmake)

> -- All valid supported_platforms from rockspec file and their cmake counterparts
> local rock2cmake = {
>   ["unix"] = "UNIX",
>   ["windows"] = "WIN32", -- ?
>   ["win32"] = "WIN32",
>   ["cygwin"] = "CYGWIN",
>   ["macosx"] = "UNIX", -- ?
>   ["linux"] = "UNIX", -- ?
>   ["freebsd"] = "UNIX" -- ?
>   }
>
> -- Create check for case when we are using unsupported platform
> if rockspec.supported_platforms ~= nil then
>   local supported_platforms = {}
>   for _, plat in pairs(rockspec.supported_platforms) do
>       local neg, plat = plat:match("^(!?)(.*)")
>       if neg == "!" then
if ($(rock2cmake[plat]))
    message(FATAL_ERROR "Unsupported platform (your platform was explicitly marked as not supported)")
endif()

>       else
>           table.insert(supported_platforms, plat)
>       end
>   end
>
>   -- Create check to validate if we are using supported platform
>   -- If no positive supported_platforms exists, module is portable to any platform
>   if #supported_platforms ~= 0 then
if (
>       for _, plat in pairs(supported_platforms) do
    NOT $(rock2cmake[plat]) AND
>       end
    1)
    message(FATAL_ERROR "Unsupported platform (your platform is not in list of supported platforms)")
endif()
>   end

> end
>
# FIXME Version check
> if rockspec.dependencies ~= nil then
>   for _, dep in ipairs(rockspec.dependencies) do
find_package($(dep) REQUIRED)
>   end

include_directories(
>   for _, dep in ipairs(rockspec.dependencies) do
    ${$(dep)_INCLUDE_DIRS}
>   end
)
> end

> if rockspec.external_dependencies ~= nil then
>   for ext_dep, _ in pairs(rockspec.external_dependencies) do
find_package($(ext_dep) REQUIRED)
>   end

include_directories(
>   for ext_dep, _ in pairs(rockspec.external_dependencies ) do
    ${$(ext_dep)_INCLUDE_DIRS}
>   end
)
> end

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
    local rockspec, err = load_into_table(arg[1])
    
    if not rockspec then
        print("Failed to load rockspec file (" .. arg[1] .. ")")
    else
        print("# Generated Cmake file begin")

        print(subst(intro,{
            _escape = ">",
            pairs = pairs,
            ipairs = ipairs,
            table = table,
            rockspec = rockspec
            }))
            
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
