using Pkg
Pkg.instantiate() # It is dumb that I have to do this
using Libdl
using Serialization

const perf_fd = Ref(Int64(0))
const gc_cycles = Ref(Int128(0))

const GC_LIB = "../../../gc_benchmarks.so"
lib = Libdl.dlopen(GC_LIB)
sym_reset = Libdl.dlsym(lib, :perf_event_reset)
sym_count = Libdl.dlsym(lib, :perf_event_count)
sym_get_count = Libdl.dlsym(lib, :perf_event_get_count)

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
            # Re-run with `perf` callbacks turned on
            ccall((:perf_event_start, GC_LIB), Cvoid, ())
            ccall(:jl_gc_set_cb_pre_gc, Cvoid, (Ptr{Cvoid}, Cint),
                  sym_reset, true)
            ccall(:jl_gc_set_cb_post_gc, Cvoid, (Ptr{Cvoid}, Cint),
                  sym_count, true)
            $(esc(ex))
            result = (
                value = val,
                times = (end_time - start_time),
                gc_diff = Base.GC_Diff(end_gc_num, start_gc_num),
                gc_end = end_gc_num,
                gc_cycles = ccall(sym_get_count, Clong, ()),
            )
        catch e
            @show e
            result = (
                value = e,
                times = NaN,
                gc_diff = Base.GC_Diff(end_gc_num, start_gc_num),
                gc_end = end_gc_num,
                cycles_in_gc = NaN,
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
