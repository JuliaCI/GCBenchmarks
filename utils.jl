using Pkg
Pkg.instantiate() # It is dumb that I have to do this
using Serialization

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
            result = (
                value = val,
                times = (end_time - start_time),
                gc_diff = Base.GC_Diff(end_gc_num, start_gc_num),
                gc_end = end_gc_num
            )
        catch e
            @show e
            result = (
                value = e,
                times = NaN,
                gc_diff = Base.GC_Diff(end_gc_num, start_gc_num),
                gc_end = end_gc_num
            )
        end
        "SERIALIZE" in ARGS ? serialize(stdout, result) : display(result)
    end
end
