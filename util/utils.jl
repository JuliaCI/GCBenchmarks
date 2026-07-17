using Pkg
Pkg.instantiate() # It is dumb that I have to do this
using Serialization

# Workload scaling. GCBENCH_SCALE=1 (default) runs the full benchmark; CI sets a
# small value so the suite finishes quickly and fits in a hosted runner. Numbers
# produced with SCALE != 1 are only a smoke test, not comparable perf results.
const SCALE = parse(Float64, get(ENV, "GCBENCH_SCALE", "1"))
scaled(n::Integer) = max(1, round(Int, n * SCALE))
# for sizes that must stay a power of two / tree depths: shift the exponent instead
scaled_log2(k::Integer) = max(0, k + floor(Int, log2(SCALE)))

idx = Ref{Int}(0)
thrashing_stamps = zeros(UInt64, 3)

function gc_cb_on_pressure()
    t = time_ns()
    # Once the GC's thrashing estimator trips, it notifies on every collection,
    # so notifications less than 1s apart are one episode: only count the first.
    if idx[] > 0 && t - thrashing_stamps[(idx[] - 1) % 3 + 1] < 1_000_000_000
        return nothing
    end
    thrashing_stamps[idx[] % 3 + 1] = t
    idx[] += 1
    if idx[] >= 3
        # three distinct thrashing episodes in ten seconds: abort
        if t - thrashing_stamps[idx[] % 3 + 1] <= 10_000_000_000
            print(stderr, "GCBenchmarks: GC thrashing detected (3 pressure episodes in 10s), aborting benchmark\n")
            exit(1)
        end
    end
    nothing
end

@debug "Setting GC memory pressure callback"
ccall(:jl_gc_set_cb_notify_gc_pressure, Cvoid, (Ptr{Cvoid}, Cint),
    @cfunction(gc_cb_on_pressure, Cvoid, ()), true)

macro gctime(ex)
    fc = isdefined(Base.Experimental, Symbol("@force_compile")) ?
        :(Base.Experimental.@force_compile) :
        :()
    quote
        $fc
        local result
        local start_gc_num = Base.gc_num()
        local end_gc_num = start_gc_num
        local start_time = time_ns()
        local end_time = start_time
        try
            local val = $(esc(ex))
            end_time = time_ns()
            end_gc_num = Base.gc_num()
            result = (;
                value = val,
                times = (end_time - start_time),
                gc_diff = Base.GC_Diff(end_gc_num, start_gc_num),
                gc_start = start_gc_num,
                gc_end = end_gc_num
            )
        catch e
            @show e
            result = (;
                value = e,
                times = NaN,
                gc_diff = Base.GC_Diff(end_gc_num, start_gc_num),
                gc_start = start_gc_num,
                gc_end = end_gc_num
            )
        end

        #run(`ps uxww`)
        #run(`pmap $(getpid())`)

        if "SERIALIZE" in ARGS
            # uglyness to communicate over non stdout (specifically file descriptor 3)
            @invokelatest serialize(open(RawFD(3)), result)
        else
            @invokelatest display(result)
        end
    end
end
