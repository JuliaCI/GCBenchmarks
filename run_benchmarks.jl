using Statistics
using Serialization
using Printf
using ArgParse

const JULIAVER = Base.julia_cmd()[1]

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--runs", "-n"
            help = "number of iterations"
            arg_type = Int
            default = 10
        "--threads", "-t"
            help = "number of threads"
            arg_type = Int
            default = 1
        "--bench", "-b"
            help = "if specified, runs a single benchmark"
            arg_type = String
            default = "all"
    end

    return parse_args(s)
end

gctime(stat) = stat.total_time

function run_one_bench(runs, threads, file)
    value = []
    times = []
    stats = []
    for _ in 1:runs
        r = open(deserialize, `$JULIAVER --project=. --threads=$threads $file SERIALIZE`)
        push!(value, r.value)
        push!(times, r.times)
        push!(stats, r.stats)
    end
    @printf("run time: %0.0fms min, %0.0fms max %0.0fms median\n",
       minimum(times) / 1_000_000,
       maximum(times) / 1_000_000,
       median(times) / 1_000_000)
    time = map(gctime, stats)
    @printf("gc time: %0.0fms min, %0.0fms max, %0.0fms median\n",
       minimum(time) / 1_000_000,
       maximum(time) / 1_000_000,
       median(time) / 1_000_000)
end

function run_all_benches(runs, threads)
    for category in readdir()
        @show category
        cd(category)
        for file in readdir()
            endswith(file, ".jl") || continue
            @show file
            run_one_bench(runs, threads, file)
        end
    cd("..")
    end
end

function main()
    args = parse_commandline()
    JULIAVER = Base.julia_cmd()[1]
    bench, runs, threads = args["bench"], args["runs"], args["threads"]

    dir = joinpath(@__DIR__, "benches")
    cd(dir)
    if bench == "all"
        run_all_benches(runs, threads)
    else
        path, file = splitpath(bench)
        cd(path)
        run_one_bench(runs, threads, file)
    end
end

main()

