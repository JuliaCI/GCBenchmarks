# Usage:
#   julia run_one_benchmark.jl [<benchmark> <#runs> <#threads>]

using Statistics
using Serialization
using Printf

gctime(stat) = stat.total_time

const BENCH = isempty(ARGS) ? "benches/append/append.jl" : ARGS[1]
const RUNS = isempty(ARGS) ? 10 : parse(Int, ARGS[2])
const THREADS = isempty(ARGS) ? 1 : parse(Int, ARGS[3])
const JULIAVER = Base.julia_cmd()[1]

path = split(BENCH, "/")
file = pop!(path)
path = join(path, "/")

dir = joinpath(@__DIR__, path)
cd(dir)
@printf("Running Benchmark path = %s file = %s times = %d threads = %d\n", path, file, RUNS, THREADS)
@show BENCH

value = []
times = []
stats = []
for _ in 1:RUNS
   r = open(deserialize, `$JULIAVER --project=. --threads=$THREADS $file SERIALIZE`)
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
   minimum(time)/ 1_000_000,
   maximum(time)/ 1_000_000,
   median(time) / 1_000_000)
