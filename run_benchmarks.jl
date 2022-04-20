using Statistics
using Serialization
import Base.GC_Diff

const RUNS = isempty(ARGS) ? 10 : parse(Int, ARGS[1])
const JULIAVER = Base.julia_cmd()[1]
dir = joinpath(@__DIR__, "benches")
cd(dir)
for category in readdir()
    @show category
    cd(category)
    for test in readdir()
        endswith(test, ".jl") || continue
        @show test
        result = (value=[], time=[], bytes=[], gctime=[], gcstats=[])
        for _ in 1:RUNS
            r = open(deserialize, `$JULIAVER --project=. $test SERIALIZE`)
            push!(result.value,   r.value)
            push!(result.time,    r.time)
            push!(result.bytes,   r.bytes)
            push!(result.gctime,  r.gctime)
            push!(result.gcstats, r.gcstats)
        end
        #result=(value, time, bytes, gctime, gcstats)
        println("median time: ", median(result.time))
        println("mean GC time: ", result.gctime)
    end
    cd("..")
end

