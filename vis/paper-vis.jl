using CairoMakie
using CSV
using DataFrames
using Makie
using Statistics
using StatsBase

function dataset_name(march::String, concurrent_sweeping_enabled::Bool)
    return joinpath(
        "data",
        "results-$march-" * (concurrent_sweeping_enabled ? "enabled" : "disabled") * ".csv",
    )
end

function get_all_benchmarks_in_category(category::String)
    # find all `*.jl` files in the benchmark/$category directory
    benchmarks = String[]
    for dir in readdir(joinpath("benches", category))
        if isdir(joinpath("benches", category, dir))
            for file in readdir(joinpath("benches", category, dir))
                if endswith(file, ".jl")
                    push!(benchmarks, file)
                end
            end
        end
    end
    return benchmarks
end

function latexify_benchmark_name(benchmark::String)
    # Replace underscores with backslashes
    return replace(benchmark, "_" => "\\_")
end

function get_gc_and_e2e_times(
    march::String,
    benchmark::String,
    concurrent_sweeping_enabled::Bool,
)
    @info "Getting GC and E2E times for $benchmark with concurrent page sweeping $(concurrent_sweeping_enabled ? "enabled" : "disabled")"
    # Read the CSV data into a DataFrame
    data = CSV.read(dataset_name(march, concurrent_sweeping_enabled), DataFrame)
    # Filter those such that file == benchmark
    data = data[data[!, :file].==benchmark, :]
    # Get all the GC times and E2E times (don't filter by GC threads)
    gctime = data[!, :gc_time]
    e2etime = data[!, :time]
    return gctime, e2etime
end

# Build a LaTeX table for the the performance with concurrent sweeping enabled compared to disabled
# Table should have the format:
# \begin{table*}[t]
# \begin{tabular}{|c|c|c|}
# \hline
# Benchmark & $\frac{\text{GC Time Concurrent Sweeping Enabled}}{\text{GC Time Concurrent Sweeping Disabled}}$& $\frac{\text{E2E Time Concurrent Sweeping Enabled}}{\text{E2E Time Concurrent Sweeping Disabled}}$\\
# \hline
# ...
# \end{tabular}
# \caption{Comparison of total GC time and end-to-end time for concurrent page sweeping enabled and disabled (lower is better). Results for aarch64 are shown in parentheses.}
function build_latex_table_for_single_threaded_perf()
    benchmarks = ["objarray.jl", "tree_immutable.jl", "tree_mutable.jl"]
    # Create a string to store the LaTeX code
    latex_table = "\\begin{table*}[t]\n\\begin{tabular}{|c|c|c|}\n\\hline\nBenchmark & \$\\frac{\\text{GC Time Concurrent Sweeping Enabled}}{\\text{GC Time Concurrent Sweeping Disabled}}\$& \$\\frac{\\text{E2E Time Concurrent Sweeping Enabled}}{\\text{E2E Time Concurrent Sweeping Disabled}}\$\\\\\n\\hline\n"
    # For each benchmark, get the GC and E2E times for each microarchitecture
    for benchmark in benchmarks
        gctime_ratio_x86_64 = 1.0
        e2etime_ratio_x86_64 = 1.0
        gctime_ratio_aarch64 = 1.0
        e2etime_ratio_aarch64 = 1.0
        # For each benchmark, get the GC and E2E times for each microarchitecture
        for march in ["x86_64", "aarch64"]
            # Get the GC and E2E times for concurrent page sweeping enabled and disabled
            gctime_enabled, e2etime_enabled = get_gc_and_e2e_times(march, benchmark, true)
            gctime_disabled, e2etime_disabled =
                get_gc_and_e2e_times(march, benchmark, false)
            # Calculate the ratios of the GC and E2E times
            if march == "x86_64"
                gctime_ratio_x86_64 = geomean(gctime_enabled) / geomean(gctime_disabled)
                e2etime_ratio_x86_64 = geomean(e2etime_enabled) / geomean(e2etime_disabled)
            else
                gctime_ratio_aarch64 = geomean(gctime_enabled) / geomean(gctime_disabled)
                e2etime_ratio_aarch64 = geomean(e2etime_enabled) / geomean(e2etime_disabled)
            end
        end
        # Truncate the ratios to 2 decimal places
        gctime_ratio_x86_64 = round(gctime_ratio_x86_64; digits=2)
        e2etime_ratio_x86_64 = round(e2etime_ratio_x86_64; digits=2)
        gctime_ratio_aarch64 = round(gctime_ratio_aarch64; digits=2)
        e2etime_ratio_aarch64 = round(e2etime_ratio_aarch64; digits=2)
        # Add the benchmark and the ratios to the LaTeX table. aarch64 results are shown in parentheses
        # don't forget the \hline at the end!!!
        latex_table *=
            latexify_benchmark_name(benchmark) * " & " * "$gctime_ratio_x86_64" * " (" * "$gctime_ratio_aarch64" * ")" * " & " * "$e2etime_ratio_x86_64" * " (" * "$e2etime_ratio_aarch64" * ")" * "\\\\\n"
        # Add a horizontal line to the LaTeX table
        latex_table *= "\\hline\n"
    end
    # Add the caption to the LaTeX table
    latex_table *=
        "\\end{tabular}\n\\caption{Comparison of total GC time and end-to-end time for concurrent page sweeping enabled and disabled (lower is better). Results for aarch64 are shown in parentheses.}\n"
    latex_table *= "\\end{table*}"
    # Write the LaTeX table to a file
    open("concurrent_page_sweeping_perf.tex", "w") do io
        write(io, latex_table)
    end
end

function main()
    # Build the LaTeX table for the single-threaded performance
    build_latex_table_for_single_threaded_perf()
end

main()
