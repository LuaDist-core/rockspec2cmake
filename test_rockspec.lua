package = "test_package"
version = "0.0-0"

source =
{
    url = "git://github.com/.../....git",
    tag = "0.0-0"
}

supported_platforms =
{
    "linux",
    "macosx",
    "!freebsd",
}

build =
{
    copy_directories = {"test", "examples"},
    type = "builtin",

    modules =
    {
        ["lua.module.1"] = "src/test/one.lua",
        ["lua.module.2"] = "src/test/two.lua",

        ["c_module_1"] =
        {
            sources = {"src/c_module_1.c"},
            defines = {"MOD1_DEFINE"},
            libraries = {"1_lib_1", "1_lib_2"},
            incdirs = {"test/inc/dir"},
            libdirs = {"test/lib/dir"},
        },
    },

    install =
    {
        lua = {["lua.test"] = "src/a.lua",},
        conf = {["cnf"] = "dep/a.cnf",},
        bin = {["bin"] = "bin/b",},
        lib = {["lib"] = "lib/not_linux_lib.dll"}
    },

    platforms =
    {
        linux =
        {
            modules =
            {
                ["linux_only_module"] = "src/test/linux_only.lua",

                ["c_module_1"] =
                {
                    defines = {"LINUX_DEFINE"},
                },
            },

            install = {lib = {["lib"] = "lib/lib.so"}},
        }
    }
}
