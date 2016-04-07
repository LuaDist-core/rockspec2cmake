local r2cmake = require 'rockspec2cmake'

if #arg ~= 1 then
    print("Usage: lua rockspec2cmake.lua rockspec_file")
else
    local rockspec = load_rockspec(arg[1])

    if not rockspec then
        print("Failed to load rockspec file (" .. arg[1] .. ")")
    else
        local cmake, err = r2cmake.process_rockspec(rockspec)

        if not cmake then
            print("Fatal error, cmake not generated: " .. err)
        else
            print(cmake)
        end
     end
end
