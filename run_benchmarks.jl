const doc = """run_benchmarks.jl -- GC benchmarks test harness
Usage:
    run_benchmarks.jl (serial|multithreaded|slow) (all|<category> [<name>]) [options]
    run_benchmarks.jl -h | --help
    run_benchmarks.jl --version
Options:
    -n <runs>, --runs=<runs>              Number of runs for each benchmark [default: 10].
    -t <threads>, --threads=<threads>     Number of threads to use [default: 1].
    -s <max>, --scale=<max>               Maximum number of threads for scaling test.
    -h, --help                            Show this screen.
    --version                             Show version.
    --json                                Serializes output to `json` file
"""

using DocOpt
using JSON
using PrettyTables
using Printf
using Serialization
using Statistics

const args = docopt(doc, version = v"0.1.1")
const JULIAVER = Base.julia_cmd()[1]

# times in ns
# TODO: get better stats
function get_stats(times::Vector)
    return [minimum(times), median(times), maximum(times), std(times)]
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

function run_bench(runs, threads, file, show_json = false)
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
    mark_time = get_stats(map(stat->stat.total_mark_time, gc_end)) ./ 1_000_000
    sweep_time = get_stats(map(stat->stat.total_sweep_time, gc_end)) ./ 1_000_000
    max_pause = get_stats(map(stat->stat.max_pause, gc_end)) ./ 1_000_000
    time_to_safepoint = get_stats(map(stat->stat.time_to_safepoint, gc_end)) ./ 1_000
    max_mem = get_stats(map(stat->stat.max_memory, gc_end)) ./ 1024^2
    pct_gc = get_stats(map((t,stat)->(stat.total_time/t), times, gc_diff)) .* 100

    header = (["", "total time", "gc time", "mark time", "sweep time", "max GC pause", "time to safepoint", "max heap", "percent gc"],
              ["", "ms",         "ms",       "ms",          "ms",       "ms",          "us",                "MB",       "%"        ])
    labels = ["minimum", "median", "maximum", "stdev"]
    highlighters = highlight_col(4, 10, 100) # max pause
    append!(highlighters, highlight_col(5, 1, 10)) # time to safepoint
    append!(highlighters, highlight_col(7, 10, 50)) # pct gc
    highlighters = Tuple(highlighters)
    if show_json
        data = Dict([("total time", total_stats),
                     ("gc time", gc_time),
                     ("mark time", mark_time),
                     ("sweep time", sweep_time),
                     ("max pause", max_pause),
                     ("ttsp", time_to_safepoint),
                     ("max memory", max_mem),
                     ("pct gc", pct_gc)])
        JSON.print(data)
    else
        data = hcat(labels, total_stats, gc_time, mark_time, sweep_time, max_pause, time_to_safepoint, max_mem, pct_gc)
        pretty_table(data; header, formatters=ft_printf("%0.0f"), highlighters)
    end
end

function run_category_files(benches, args, show_json = false)
    local runs = parse(Int, args["--runs"])
    local threads = parse(Int, args["--threads"])
    local max = if isnothing(args["--scale"]) 0 else parse(Int, args["--scale"]) end
    for bench in benches
        if !show_json
            @show bench
        end
        if isnothing(args["--scale"])
            run_bench(runs, threads, bench, show_json)
        else
            local n = 0
            while true
                threads = 2^n
                threads > max && break
                @show threads
                run_bench(runs, threads, bench, show_json)
                n += 1
            end
        end
    end
end

function run_all_categories(args, show_json = false)
    for category in readdir()
        @show category
        cd(category)
        benches = filter(f -> endswith(f, ".jl"), readdir())
        run_category_files(benches, args, show_json)
        cd("..")
    end
end

function main(args)
    cd(joinpath(@__DIR__, "benches"))

    # validate choices
    if !isnothing(args["--scale"])
        @assert args["--threads"] == "1" "Specify either --scale or --threads."
    end

    # select benchmark class
    if args["serial"]
        cd("serial")
    elseif args["multithreaded"]
        cd("multithreaded")
    else # args["slow"]
        cd("slow")
    end

    show_json = args["--json"]

    if args["all"]
        run_all_categories(args, show_json)
    else
        cd(args["<category>"])
        benches = if isnothing(args["<name>"])
            filter(f -> endswith(f, ".jl"), readdir())
        else
            ["$(args["<name>"]).jl"]
        end
        run_category_files(benches, args, show_json)
    end
end

main(args)
