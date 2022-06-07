add_rules("mode.debug", "mode.release")

local isMingw = false
set_arch("x86")
-- add_rules("c.unity_build")
-- add_rules("c++.unity_build")
-- add_cxflags("-march=i686 -msse -msse2 -mfpmath=sse", {force = true})

option("unicode")
    set_default(false)
    set_showmenu(true)
    add_defines("UNICODE", "_UNICODE")
    if (isMingw) then
        add_cxflags("-municode")
        add_ldflags("-municode", {force = true})
    else
        add_cxflags("/D UNICODE")
    end

option("utf8")
    set_default(true)
    set_showmenu(true)
    if (isMingw) then
    else
        add_cxflags("/utf-8", {force = true})
    end

target("minilua")
    set_kind("binary")
    add_options("utf8", "unicode")
    add_files("src/host/minilua.c")

target("buildvm")
    set_kind("binary")
    before_build(function (target)
        local args = {
            "dynasm/dynasm.lua",
            "-LN",
            "-D","WIN",
            "-D", "JIT",
            "-D", "FFI"
        }

        local dasc = nil
        if target:is_arch("x86") then
            dasc = "src/vm_x86.dasc"
        else
            table.insert(args, "-D")
            table.insert(args, "P64")
            dasc = "src/vm_x64.dasc"
        end
        table.insert(args, "-o")
        table.insert(args, "src/host/buildvm_arch.h")
        table.insert(args, dasc)
        os.runv(
            target:targetdir().."/minilua",
            args
        )
        print("generate buildvm_arch.h done")
    end)
    add_options("utf8", "unicode")
    add_includedirs("dynasm")
    add_includedirs("src")
    add_files("src/host/buildvm*.c")

local ALL_LIB = {
    "src/lib_base.c",
    "src/lib_math.c",
    "src/lib_bit.c",
    "src/lib_string.c",
    "src/lib_table.c",
    "src/lib_io.c",
    "src/lib_os.c",
    "src/lib_package.c",
    "src/lib_debug.c",
    "src/lib_jit.c",
    "src/lib_ffi.c",
    "src/lib_buffer.c"
}

function generateVm(target) 
    for _, args in ipairs({
        -- {
        --     "-m",
        --     "peobj",
        --     "-o",
        --     "src/lj_vm.obj"
        -- },
        {
            "-m",
            "nasm",
            "-o",
            "src/lj_vm.asm"
        },
        table.join({
            "-m",
            "bcdef",
            "-o",
            "src/lj_bcdef.h"
        }, ALL_LIB),
        table.join({
            "-m",
            "ffdef",
            "-o",
            "src/lj_ffdef.h"
        }, ALL_LIB),
        table.join({
            "-m",
            "libdef",
            "-o",
            "src/lj_libdef.h"
        }, ALL_LIB),
        table.join({
            "-m",
            "recdef",
            "-o",
            "src/lj_recdef.h"
        }, ALL_LIB),
        table.join({
            "-m",
            "vmdef",
            "-o",
            "src/jit/vmdef.lua"
        }, ALL_LIB),
        {
            "-m",
            "folddef",
            "-o",
            "src/lj_folddef.h",
            "src/lj_opt_fold.c"
        }
    }) do
        os.runv(target:targetdir().."/buildvm", args)
    end
    print("generate buildvm")
end

target("luajit")
    set_kind("binary")
    before_build(generateVm)
    add_options("utf8", "unicode")
    add_includedirs("src")
    add_files("src/lj_*.c", "src/lib_*.c")
    add_files("src/luajit.c")
    add_files("src/lj_vm.asm")
    set_toolset("as", "nasm")
    -- add_files("src/lj_vm.obj")
    add_defines(
        "_CRT_SECURE_NO_DEPRECATE",
        "_CRT_STDIO_INLINE=__declspec(dllexport)__inline"
    )
    -- add_defines("LUA_BUILD_AS_DLL")
target("lua")
    set_kind("shared")
    before_build(generateVm)
    add_options("utf8", "unicode")
    add_includedirs("src")
    add_files("src/lj_*.c", "src/lib_*.c")
    set_toolset("as", "nasm")
    add_files("src/lj_vm.asm")
    -- add_files("src/lj_vm.obj")
    add_defines(
        "_CRT_SECURE_NO_DEPRECATE",
        "_CRT_STDIO_INLINE=__declspec(dllexport)__inline"
    )
