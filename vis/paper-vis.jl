using CairoMakie
using CSV
using DataFrames
using Makie
using Statistics
using StatsBase

function dataset_name(march::String, category::String)
    return joinpath("data", "results-$category-$march.csv")
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

function get_single_threaded_gc_and_e2e_times(
    march::String,
    category::String,
    benchmark::String,
)
    # Read the CSV data into a DataFrame
    data = CSV.read(dataset_name(march, category), DataFrame)
    # Get the dataframe such that `file == benchmark`
    benchmark_data = filter(row -> row[:file] == benchmark, data)
    # Get all the GC times and E2E times (don't filter by GC threads)
    gctime = benchmark_data[!, :gc_time]
    e2etime = benchmark_data[!, :time]
    return gctime, e2etime
end

# Build a LaTeX table for the single-threaded performance
# of 1.9 (which should be the files data/results-1.9-*.csv) and
# dev (which should be the files data/results-*.csv)
# The table should have the following format:
# | Benchmark | GC_Time_1.9 / GC_Time_dev | E2E_Time_1.9 / E2E_Time_dev |
# The corresponding LaTeX code for the table should have the form:
# \begin{table*}[t]
# \begin{tabular}{|c|c|c|}
# \hline
# Benchmark & GC Time DEV / GC Time 1.9 & E2E Time DEV / E2E Time 1.9 \\
# \hline
# ...
# \end{tabular}
# \caption{Comparison of total GC time and end-to-end time for single-threaded performance of 1.9 and Julia's development branch with 2 GC threads (lower is better).
# Times for x86_64 are shown before the parentheses and times for aarch64 are shown in parentheses.}
# \end{table*}
# Note that we will be taking the geometric mean of the GC and E2E times
# accross both microarchitectures.
function build_latex_table_for_single_threaded_perf()
    categories = ["serial", "multithreaded", "slow"]
    # Create a string to store the LaTeX code
    latex_table = "\\begin{table*}[t]\n\\begin{tabular}{|c|c|c|}\n\\hline\nBenchmark & \$\\frac{\\text{GC Time DEV}}{\\text{GC Time 1.9}}\$& \$\\frac{\\text{E2E Time DEV}}{\\text{E2E Time 1.9}}\$\\\\\n\\hline\n"
    for category in categories
        benchmarks = get_all_benchmarks_in_category(category)
        for benchmark in benchmarks
            gc_times_19_x86_64, e2e_times_19_x86_64 = get_single_threaded_gc_and_e2e_times(
                "x86_64",
                "1.9-" * category,
                benchmark,
            )
            gc_times_19_aarch64, e2e_times_19_aarch64 = get_single_threaded_gc_and_e2e_times(
                "aarch64",
                "1.9-" * category,
                benchmark,
            )
            gc_times_dev_x86_64, e2e_times_dev_x86_64 = get_single_threaded_gc_and_e2e_times(
                "x86_64",
                category,
                benchmark,
            )
            gc_times_dev_aarch64, e2e_times_dev_aarch64 = get_single_threaded_gc_and_e2e_times(
                "aarch64",
                category,
                benchmark,
            )
            # Take the geometric mean of the GC and E2E times
            gc_time_ratio_x86_64 = geomean(gc_times_dev_x86_64) / geomean(gc_times_19_x86_64)
            gc_time_ratio_aarch64 = geomean(gc_times_dev_aarch64) / geomean(gc_times_19_aarch64)
            e2e_time_ratio_x86_64 = geomean(e2e_times_dev_x86_64) / geomean(e2e_times_19_x86_64)
            e2e_time_ratio_aarch64 = geomean(e2e_times_dev_aarch64) / geomean(e2e_times_19_aarch64)
            # Truncate to two decimal places
            gc_time_ratio_x86_64 = round(gc_time_ratio_x86_64, digits=2)
            gc_time_ratio_aarch64 = round(gc_time_ratio_aarch64, digits=2)
            e2e_time_ratio_x86_64 = round(e2e_time_ratio_x86_64, digits=2)
            e2e_time_ratio_aarch64 = round(e2e_time_ratio_aarch64, digits=2)
            # Latexify the benchmark name
            benchmark = latexify_benchmark_name(benchmark)
            # Add the benchmark and the GC and E2E time ratios to the LaTeX table, don't forget the hline at the end
            latex_table *= "$benchmark & $gc_time_ratio_x86_64 ($gc_time_ratio_aarch64) & $e2e_time_ratio_x86_64 ($e2e_time_ratio_aarch64) \\\\\n\\hline\n"
        end
    end
    latex_table *= "\\end{tabular}\n\\caption{Comparison of total GC time and end-to-end time for single-threaded performance of 1.9 and Julia's development branch with 2 GC threads (lower is better). Times for x86\\_64 are shown before the parentheses and times for aarch64 are shown in parentheses.}\n\\end{table*}"
    # Write the LaTeX table to a file
    open("single_threaded_perf.tex", "w") do io
        println(io, latex_table)
    end
end

function main()
    # Build the LaTeX table for the single-threaded performance
    build_latex_table_for_single_threaded_perf()
end

main()
