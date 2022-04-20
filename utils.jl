using Serialization

macro gctime(ex)
    fc = isdefined(Base.Experimental, Symbol("@force_compile")) ? :(Base.Experimental.@force_compile) : :()
    quote
        $fc
        local stats = Base.gc_num()
        local t0 = time_ns()
        local val = $(esc(ex))
        local t1 = time_ns()
        local diff = Base.GC_Diff(Base.gc_num(), stats)
        result = (value=val, time=(t1 - t0) / 1e9, bytes=diff.allocd, gctime=diff.total_time/(1e9*n), gcstats=diff)
        "SERIALIZE" in ARGS ? serialize(stdout, result) : display(result)
    end
end
