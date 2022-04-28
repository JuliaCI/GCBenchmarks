using Statistics
using Serialization
using Printf

gctime(stat) = stat.total_time
max_pause(gc_num) = gc_num.max_pause
max_memory(gc_num) = gc_num.max_memory

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
(value,times,stats,gc_num)= result
@printf("run time: %0.0fms min, %0.0fms max %0.0fms median\n",
   minimum(result.times) / 1_000_000,
   maximum(result.times) / 1_000_000,
   median(result.times)  / 1_000_000)

time = map(gctime, stats)
@printf("gc time: %0.0fms min, %0.0fms max, %0.0fms median\n",
   minimum(time)/ 1_000_000,
   maximum(time)/ 1_000_000,
   median(time) / 1_000_000)

pause = map(max_pause, gc_num)
@printf("max pause = %0.0fms\n", maximum(pause)/ 1_000_000)

max_mem = map(max_memory, gc_num)
@printf("max memory = %0.0fmb\n", maximum(max_mem)/ 1_000_000)
