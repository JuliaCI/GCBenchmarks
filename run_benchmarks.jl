using Statistics
using Serialization
using Printf

const RUNS = isempty(ARGS) ? 10 : parse(Int, ARGS[1])
const JULIAVER = Base.julia_cmd()[1]
dir = joinpath(@__DIR__, "benches")
cd(dir)

gctime(stat) = stat.total_time

for category in readdir()
    @show category
    cd(category)
    for test in readdir()
        endswith(test, ".jl") || continue
        @show test
        value=[]
        times=[]
        stats=[]
        for _ in 1:RUNS
            r = open(deserialize, `$JULIAVER --project=. $test SERIALIZE`)
            push!(value, r.value)
            push!(times, r.times)
            push!(stats, r.stats)
        end
        @printf("run time: %0.0fms min, %0.0fms max %0.0fms median\n",
           minimum(result.times)/ 1_000_000,
           maximum(result.times)/ 1_000_000,
           median(result.times) / 1_000_000)
        time = map(gctime, stats)
        @printf("gc time: %0.0fms min, %0.0fms max, %0.0fms median\n",
           minimum(time)/ 1_000_000,
           maximum(time)/ 1_000_000,
           median(time) / 1_000_000)
    end
    cd("..")
end

