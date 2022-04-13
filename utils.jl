using Serialization



macro gctime(ex)
    fc = isdefined(Base.Experimental, Symbol("@force_compile")) ? :(Base.Experimental.@force_compile) : :()
    quote
        $fc
        n = isempty(ARGS) ? 1 : parse(Int, ARGS[1])
        local times = Vector{Float64}(undef, n)
        local vals = Vector{Any}(undef, n)
        local stats = Vector{Base.GC_Num}(undef, n)
        for i in 1:n
            start = time_ns()
            vals[i] = $(esc(ex))
            times[i] = time_ns() - start
            stats[i] = Base.gc_num()
        end
        result = (value=vals, times=times, stasts=stats)
        ARGS[end] == "SERIALIZE" ? serialize(stdout, result) : display(result)
    end
end
