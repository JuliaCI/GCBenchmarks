using Serialization
macro gctime(ex)
    quote
        @gctime 1 $(esc(ex))
    end
end

macro gctime(n, ex)
    quote
        Base.Experimental.@force_compile
        local times = Vector{Float64}(undef, $(esc(n)))
        local vals = Vector{Any}(undef, $(esc(n)))
        local stats = Base.gc_num()
        t0 = time_ns()
        for i in 1:$(esc(n))
            vals[i] = $(esc(ex))
            times[i] = time_ns()
        end
        local diff = Base.GC_Diff(Base.gc_num(), stats)
        @. times = (times - t0) / 1e9
        result = (value=vals, times=times, bytes=diff.allocd, gctime=diff.total_time/(1e9*$(esc(n))), gcstats=diff)
        serialize(stdout, result)
    end
end
