using Statistics
using Serialization
using Printf
using ArgParse
using PrettyTables

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

# times in ns
# TODO: get better stats
function get_stats(times::Vector)
    return [minimum(times), median(times), maximum(times)]
end

"""
    Highlights cells in a column based on value
        green if less than lo
        yellow if between lo and hi
        red if above hi
"""
function highlight_col(col, lo, hi)
    [Highlighter((data,i,j) -> (j == col) && data[i, j] <= lo; foreground=:green),
     Highlighter((data,i,j) -> (j == col) && lo < data[i, j] < hi; foreground=:yellow),
     Highlighter((data,i,j) -> (j == col) && hi <= data[i, j]; foreground=:red),]
end

function run_one_bench(runs, threads, file)
    value = []
    times = []
    gc_diff = []
    gc_end = []
    for _ in 1:runs
        # uglyness to communicate over non stdout (specifically file descriptor 3)
        p = Base.PipeEndpoint()
        cmd = `$JULIAVER --project=. --threads=$threads $file SERIALIZE`
        cmd = run(Base.CmdRedirect(cmd, p, 3), stdin, stdout, stderr, wait=false)
        r = deserialize(p)
        @assert success(cmd)
        # end uglyness
        push!(value, r.value)
        push!(times, r.times)
        push!(gc_diff, r.gc_diff)
        push!(gc_end, r.gc_end)
    end
    total_stats = get_stats(times) ./ 1_000_000
    gc_time = get_stats(map(stat->stat.total_time, gc_end)) ./ 1_000_000
    max_pause = get_stats(map(stat->stat.max_pause, gc_end)) ./ 1_000_000
    time_to_safepoint = get_stats(map(stat->stat.time_to_safepoint, gc_end)) ./ 1_000_000
    max_mem = get_stats(map(stat->stat.max_memory, gc_end)) ./ 1024^2
    pct_gc = get_stats(map((t,stat)->(stat.total_time/t), times, gc_diff)) .* 100

    header = (["", "total time", "gc time", "max GC pause", "time to safepoint", "max heap", "percent gc"],
              ["", "ms",         "ms",       "ms",          "ms",                "MB",       "%"        ])
    labels = ["minimum", "median", "maximum"]
    highlighters = highlight_col(4, 10, 100) # max pause
    append!(highlighters, highlight_col(5, 1, 10)) # time to safepoint
    append!(highlighters, highlight_col(7, 10, 50)) # pct gc
    highlighters = Tuple(highlighters)
    data = hcat(labels, total_stats, gc_time, max_pause, time_to_safepoint, max_mem, pct_gc)
    pretty_table(data; header, formatters=ft_printf("%0.0f"), highlighters)
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
