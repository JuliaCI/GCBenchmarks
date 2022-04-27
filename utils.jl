using Serialization



macro gctime(ex)
    fc = isdefined(Base.Experimental, Symbol("@force_compile")) ? :(Base.Experimental.@force_compile) : :()
    quote
        $fc
        n = isempty(ARGS) ? 1 : parse(Int, ARGS[1])
        local times = Vector{Float64}(undef, n)
        local vals = Vector{Any}(undef, n)
        local stats = Vector{Base.GC_Diff}(undef, n)
        for i in 1:n
            start_time = time_ns()
            start_gc_num = Base.gc_num()
            vals[i] = $(esc(ex))
            times[i] = time_ns() - start_time
            stats[i] = Base.GC_Diff(Base.gc_num(), start_gc_num)
        end
        result = (value=vals, times=times, stasts=stats)
        ARGS[end] == "SERIALIZE" ? serialize(stdout, result) : display(result)
    end
end
