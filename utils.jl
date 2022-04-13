using Serialization

macro gctime(ex)
    fc = isdefined(Base.Experimental, Symbol("@force_compile")) ? :(Base.Experimental.@force_compile) : :()
    quote
        $fc
        n = isempty(ARGS) ? 1 : parse(Int, ARGS[1])
        local times = Vector{Float64}(undef, n+1)
        local vals = Vector{Any}(undef, n)
        local stats = Base.gc_num()
        times[1] = time_ns()
        for i in 2:n+1
            vals[i] = $(esc(ex))
            times[i] = time_ns()
        end
        local gc_diff = Base.GC_Diff(Base.gc_num(), stats)
        times = diff(times) ./ 1e9
        result = (value=vals, times=times, bytes=gc_diff.allocd, gctime=gc_diff.total_time/(1e9*n), gcstats=gc_diff)
        ARGS[end] == "SERIALIZE" ? serialize(stdout, result) : display(result)
    end
end
