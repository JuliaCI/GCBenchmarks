using Serialization

macro gctime(ex)
    fc = isdefined(Base.Experimental, Symbol("@force_compile")) ? :(Base.Experimental.@force_compile) : :()
    quote
        $fc
        n = isempty(ARGS) ? 1 : parse(Int, ARGS[1])
        local times = Vector{Float64}(undef, n)
        local vals = Vector{Any}(undef, n)
        local stats = Base.gc_num()
        t0 = time_ns()
        for i in 1:n
            vals[i] = $(esc(ex))
            times[i] = time_ns()
        end
        local diff = Base.GC_Diff(Base.gc_num(), stats)
        @. times = (times - t0) / 1e9
        result = (value=vals, times=times, bytes=diff.allocd, gctime=diff.total_time/(1e9*n), gcstats=diff)
        ARGS[end] == "SERIALIZE" ? serialize(stdout, result) : display(result)
    end
end
