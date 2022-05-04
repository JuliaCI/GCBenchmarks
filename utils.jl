using Pkg
Pkg.instantiate() # It is dumb that I have to do this
using Serialization



macro gctime(ex)
    fc = isdefined(Base.Experimental, Symbol("@force_compile")) ?
        :(Base.Experimental.@force_compile) :
        :()
    quote
        $fc
        local start_gc_num = Base.gc_num()
        local start_time = time_ns()
        local val = $(esc(ex))
        local end_time = time_ns()
        local end_gc_num = Base.gc_num()
        result = (
            value = val,
            times = (end_time - start_time),
            stats = Base.GC_Diff(end_gc_num, start_gc_num),
        )
        "SERIALIZE" in ARGS ? serialize(stdout, result) : display(result)
    end
end
