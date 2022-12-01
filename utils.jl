using Pkg
Pkg.instantiate() # It is dumb that I have to do this
using Serialization

module ITT
    import Libdl
    const GC_LIB = joinpath(@__DIR__, "lib/itt.so")

    function __init__()
        lib = Libdl.dlopen(GC_LIB)
        sym_init = Libdl.dlsym(lib, :init)
        sym_begin = Libdl.dlsym(lib, :gc_begin)
        sym_end = Libdl.dlsym(lib, :gc_end)

        ccall(sym_init, Cvoid, ())
        ccall(:jl_gc_set_cb_pre_gc, Cvoid, (Ptr{Cvoid}, Cint),
                sym_begin, true)
        ccall(:jl_gc_set_cb_post_gc, Cvoid, (Ptr{Cvoid}, Cint),
                sym_end, true)
    end
end

macro gctime(ex)
    fc = isdefined(Base.Experimental, Symbol("@force_compile")) ?
        :(Base.Experimental.@force_compile) :
        :()
    quote
        $fc
        local result
        try
            local start_gc_num = Base.gc_num()
            local start_time = time_ns()
            local val = $(esc(ex))
            local end_time = time_ns()
            local end_gc_num = Base.gc_num()
            result = (
                value = val,
                times = (end_time - start_time),
                gc_diff = Base.GC_Diff(end_gc_num, start_gc_num),
                gc_end = end_gc_num
            )
        catch e
            @show e
            result = (
                value = e,
                times = NaN,
                gc_diff = Base.GC_Diff(end_gc_num, start_gc_num),
                gc_end = end_gc_num
            )
        end
        if "SERIALIZE" in ARGS
            # uglyness to communicate over non stdout (specifically file descriptor 3)
            serialize(open(RawFD(3)), result)
        else
            display(result)
        end
    end
end
