using Pkg
Pkg.instantiate() # It is dumb that I have to do this
using Libdl
using Serialization

const GC_LIB = "../../../gc_benchmarks.so"
const lib = Libdl.dlopen(GC_LIB)
const sym_start = Libdl.dlsym(lib, :perf_event_start)
const sym_reset = Libdl.dlsym(lib, :perf_event_reset)
const sym_count = Libdl.dlsym(lib, :perf_event_count)
const sym_get_count = Libdl.dlsym(lib, :perf_event_get_count)

const count_cycles = ARGS[2]

macro gctime(ex)
    fc = isdefined(Base.Experimental, Symbol("@force_compile")) ?
        :(Base.Experimental.@force_compile) :
        :()
    quote
        $fc
        local result
        try
            if count_cycles == "--cycles-count"
                ccall(sym_start, Cvoid, ())
                ccall(:jl_gc_set_cb_pre_gc, Cvoid, (Ptr{Cvoid}, Cint),
                      sym_reset, true)
                ccall(:jl_gc_set_cb_post_gc, Cvoid, (Ptr{Cvoid}, Cint),
                      sym_count, true)
            end
            local start_gc_num = Base.gc_num()
            local start_time = time_ns()
            local val = $(esc(ex))
            local end_time = time_ns()
            local end_gc_num = Base.gc_num()
            result = (
                value = val,
                times = (end_time - start_time),
                gc_diff = Base.GC_Diff(end_gc_num, start_gc_num),
                gc_end = end_gc_num,
                gc_cycles = ccall(sym_get_count, Clonglong, ()),
            )
        catch e
            @show e
            result = (
                value = e,
                times = NaN,
                gc_diff = Base.GC_Diff(end_gc_num, start_gc_num),
                gc_end = end_gc_num,
                gc_cycles = NaN,
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
