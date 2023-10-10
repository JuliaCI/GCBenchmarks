using Pkg
Pkg.instantiate() # It is dumb that I have to do this
using Serialization

idx = Ref{Int}(0)
thrashing_stamps = zeros(UInt64, 3)

function gc_cb_on_pressure()
    t = time_ns()
    thrashing_stamps[idx[] % 3 + 1] = t
    idx[] += 1
    if idx[] >= 3
        # three thrashing stamps in three seconds: abort
        if t - thrashing_stamps[idx[] % 3 + 1] <= 3_000_000_000
            @ccall abort()::Cvoid
        end
    end
    nothing
end

if VERSION >= v"1.10-alpha1"
    ccall(:jl_gc_set_cb_notify_gc_pressure, Cvoid, (Ptr{Cvoid}, Cint),
        @cfunction(gc_cb_on_pressure, Cvoid, ()), true)
end

macro gctime(ex)
    fc = isdefined(Base.Experimental, Symbol("@force_compile")) ?
        :(Base.Experimental.@force_compile) :
        :()
    quote
        $fc
        local result
        GC.gc()
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
            print("EXCEPTION???")
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
