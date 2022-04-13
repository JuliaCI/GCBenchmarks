using Statistics
using Serialization
using Printf

gctime(stat) = stat.total_time

const BENCH = isempty(ARGS) ? "benches/append/append.jl" : ARGS[1]
const RUNS = isempty(ARGS) ? 10 : parse(Int, ARGS[2])
const JULIAVER = Base.julia_cmd()[1]

path = split(BENCH, "/")
file = pop!(path)
path = join(path, "/")

dir = joinpath(@__DIR__, path)
cd(dir)
@printf("Running Benchmark path = %s file = %s times = %d\n", path, file, RUNS)
@show BENCH
result = open(deserialize, `$JULIAVER --project=. $file $RUNS SERIALIZE`)
(value,times,stats)= result
@printf("run time: %0.0fs min, %0.0fs max %0.0fs median\n",
minimum(result.times)/ 1000000000,
maximum(result.times)/ 1000000000,
median(result.times) / 1000000000)
time = map(gctime, stats)
@printf("gc time: %0.0fms min, %0.0fms max, %0.0fms median\n",
minimum(time)/ 1000000,
maximum(time)/ 1000000,
median(time) / 1000000)


