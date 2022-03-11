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
        result = open(deserialize, `$JULIAVER --project=. $test $RUNS SERIALIZE`)
        #result=(value, times, bytes, gctime, gcstats)
        println("median time: ", median(result.times))
        println("mean GC time: ", result.gctime)
    end
    cd("..")
end

