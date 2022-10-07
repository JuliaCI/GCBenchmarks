using Pkg
Pkg.instantiate() # It is dumb that I have to do this
using Serialization

const perf_fd = Ref(Int64(0))
const cycles_in_gc = Ref(Int128(0))

const GC_LIB = "../../../gc_benchmarks.so"

function gc_cb_pre(full::Cint)
    perf_fc[] = ccall((:perf_event_start, GC_LIB), Int64, ())
    nothing
end

function gc_cb_post(full::Cint)
    cycles_in_gc[] += ccall((:perf_event_end, GC_LIB), Clonglong, (Cint,), (perf_fd[],))
    nothing
end

macro gctime(ex)
    fc = isdefined(Base.Experimental, Symbol("@force_compile")) ?
        :(Base.Experimental.@force_compile) :
        :()
    quote
        $fc
        local result
        ccall(:jl_gc_set_cb_pre_gc, Cvoid, (Ptr{Cvoid}, Cint),
              @cfunction(gc_cb_pre, Cvoid, (Cint,)), true)
        ccall(:jl_gc_set_cb_post_gc, Cvoid, (Ptr{Cvoid}, Cint),
              @cfunction(gc_cb_post, Cvoid, (Cint,)), true)
        try
            local start_gc_num = Base.gc_num()
            local start_time = time_ns()
            local val = $(esc(ex))
            local end_time = time_ns()
            local end_gc_num = Base.gc_num()
            @show cycles_in_gc[]
            result = (
                value = val,
                times = (end_time - start_time),
                gc_diff = Base.GC_Diff(end_gc_num, start_gc_num),
                gc_end = end_gc_num,
                cycles_in_gc = cycles_in_gc[],
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
