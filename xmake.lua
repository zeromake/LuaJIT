add_rules("mode.debug", "mode.release")

local isMingw = true
local useAsm = true
-- set_arch("x86")

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
    if (is_plat("macosx")) then
        if (is_arch("x86")) then
            add_defines("LUAJIT_TARGET=LUAJIT_ARCH_X86")
        else
            add_defines("LUAJIT_TARGET=LUAJIT_ARCH_X64")
        end
        add_defines("LJ_ARCH_HASFPU=1", "LJ_ABI_SOFTFP=0")
    end

target("buildvm")
    set_kind("binary")
    before_build(function (target)
        local args = {
            "dynasm/dynasm.lua",
            "-D", "JIT",
            "-D", "FFI"
        }
        if (is_plat("windows")) then
            table.insert(args, "-LN")
            table.insert(args, "-D")
            table.insert(args, "WIN")
        else
            table.insert(args, "-D")
            table.insert(args, "ENDIAN_LE")
            table.insert(args, "-D")
            table.insert(args, "FPU")
            table.insert(args, "-D")
            table.insert(args, "HFABI")
            table.insert(args, "-D")
            table.insert(args, "VER=")
        end

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
    local arr = {
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
    }
    
    if (is_plat("windows")) then
        if (useAsm) then
            table.insert(arr, {
                "-m",
                "nasm",
                "-o",
                "src/lj_vm.asm"
            })
        else
            table.insert(arr, {
                "-m",
                "peobj",
                "-o",
                "src/lj_vm.obj"
            })
        end
    elseif (is_plat("macosx")) then
        table.insert(arr, {
            "-m",
            "machasm",
            "-o",
            "src/lj_vm.asm"
        })
    else
        table.insert(arr, {
            "-m",
            "elfasm",
            "-o",
            "src/lj_vm.asm"
        })
    end
    for _, args in ipairs(arr) do
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
    if (is_plat("windows")) then
        if (useAsm) then
            add_files("src/lj_vm.asm")
            set_toolset("as", "nasm")
        else
            add_files("src/lj_vm.obj")
        end
    else
        add_files("src/lj_vm.asm")
    end
    if (is_plat("windows")) then
        add_defines(
            "_CRT_SECURE_NO_DEPRECATE",
            "_CRT_STDIO_INLINE=__declspec(dllexport)__inline"
        )
    elseif (is_plat("macosx")) then
        add_defines("LUAJIT_OS=LUAJIT_OS_OSX")
        add_defines("LUAJIT_UNWIND_EXTERNAL", "_LARGEFILE_SOURCE", "_FILE_OFFSET_BITS=64")
        add_undefines("_FORTIFY_SOURCE")
    end
    -- add_defines("LUA_BUILD_AS_DLL")
target("lua")
    set_kind("shared")
    before_build(generateVm)
    add_options("utf8", "unicode")
    add_includedirs("src")
    add_files("src/lj_*.c", "src/lib_*.c")
    if (is_plat("windows")) then
        if (useAsm) then
            add_files("src/lj_vm.asm")
            set_toolset("as", "nasm")
        else
            add_files("src/lj_vm.obj")
        end
    else
        add_files("src/lj_vm.asm")
    end
    add_defines(
        "_CRT_SECURE_NO_DEPRECATE",
        "_CRT_STDIO_INLINE=__declspec(dllexport)__inline"
    )
