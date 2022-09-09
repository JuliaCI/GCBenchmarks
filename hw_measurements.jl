const doc = """hw_measurements.jl -- Computes `lower-bound-overhead` from Cai et al.
Hardware counters are measured with `perf`
Usage:
    hw_measurements.jl <path_to_bin1> <path_to_bin2> <path_to_benchmark>
Options:
    -h, --help                            Show this screen.
"""

using DocOpt
using JSON
using PrettyTables
using Printf

const args = docopt(doc, version = v"0.1.1")

const NRUNS = 10
const EVENT_INDEX = 4
const FUNC_NAME_INDEX = 7

# We're missing a few `libc` (e.g. `free`) functions that are called from sweeping
# This shouldn't matter if we are comparing the lower bound overhead accross
# binaries that differ only in the mark-loop code
function match_gc_function(func_name)
   return occursin("sweep", func_name) || (occursin("gc_", func_name) && !occursin("alloc", func_name) && !occursin("finalizer", func_name))
end

function parse_event_table(perf_script_file)
    gc_event_count = 0
    total_event_count = 0
    lines = readlines(perf_script_file)
    for l in lines
        l_filtered = filter(x -> x != "", collect(eachsplit(l, " ")))
        event_count = l_filtered[EVENT_INDEX]
        func_name = l_filtered[FUNC_NAME_INDEX]
        if match_gc_function(func_name)
            gc_event_count += parse(Int64, event_count)
        end
        total_event_count += parse(Int64, event_count)
    end
    return gc_event_count, total_event_count
end

event_list = ["cycles", "instructions", "cache-misses", "page-faults"]

function run_benchmark(bin_list, f)
    if !Sys.islinux()
        error("Measurement infrastructure is only available on linux")
    end

    # Initialize event count tables
    gc_event_counts = Dict()
    total_event_counts = Dict()
    for event in event_list
        gc_event_counts[event] = []
        total_event_counts[event] = []
    end
    
    f_split = collect(eachsplit(f, "/"))
    directory = f_split[3]
    category = f_split[4]
    # remove trailing `.jl` extension
    file_name = collect(eachsplit(f_split[5], "."))[1]
    for bin in bin_list
        Printf.@printf "Running %s on %s\n" f_split[5] bin
        for event in event_list
            Printf.@printf "Measuring %s\n" event
            run(pipeline(`perf record -e $event $bin run_benchmarks.jl $directory $category $file_name -n$NRUNS`, stdout = devnull, stderr = devnull))
            run(pipeline(`perf script`, stdout = "out"))
            gc_event_count, total_event_count = parse_event_table("out") ./ NRUNS
            push!(gc_event_counts[event], gc_event_count)
            push!(total_event_counts[event], total_event_count)
        end
    end
    
    return gc_event_counts, total_event_counts
end

function build_table(bin_list, f)
    header = ["" bin_list]

    gc_event_counts, total_event_counts = run_benchmark(bin_list, f)

    # compute distilled costs and lower bound overheads
    for event in event_list
        distilled_costs = []
        for (i, _) in enumerate(bin_list)
            push!(distilled_costs, total_event_counts[event][i] - gc_event_counts[event][i])
        end
        minimum_distilled_cost = reduce(min, distilled_costs)
        lower_bound_overheads = ["LBO in $event"]
        for (i, _) in enumerate(bin_list)
            lower_bound_overheads = hcat(lower_bound_overheads, string(total_event_counts[event][i] - minimum_distilled_cost))
        end
        header = vcat(header, lower_bound_overheads)
    end

    pretty_table(header[2:end, :], header[1, :])
end

function main(args)
    bin1 = args["<path_to_bin1>"]
    bin2 = args["<path_to_bin2>"]
    benchmark = args["<path_to_benchmark>"]
    build_table([bin1 bin2], benchmark)
end

main(args)
