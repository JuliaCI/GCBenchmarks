# Usage:
#   julia run_benchmarks.jl [<#runs> <#threads>]

using Statistics
using Serialization
using Printf

const RUNS = isempty(ARGS) ? 10 : parse(Int, ARGS[1])
const THREADS = isempty(ARGS) ? 1 : parse(Int, ARGS[2])
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
        value = []
        times = []
        stats = []
        for _ in 1:RUNS
            r = open(deserialize, `$JULIAVER --project=. --threads=$THREADS $test SERIALIZE`)
            push!(value, r.value)
            push!(times, r.times)
            push!(stats, r.stats)
        end
        @printf("run time: %0.0fms min, %0.0fms max %0.0fms median\n",
           minimum(times) / 1_000_000,
           maximum(times) / 1_000_000,
           median(times)  / 1_000_000)
        time = map(gctime, stats)
        @printf("gc time: %0.0fms min, %0.0fms max, %0.0fms median\n",
           minimum(time) / 1_000_000,
           maximum(time) / 1_000_000,
           median(time)  / 1_000_000)
    end
    cd("..")
end
