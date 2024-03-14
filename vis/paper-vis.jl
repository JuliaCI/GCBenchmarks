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

function get_gc_and_e2e_times(
    march::String,
    category::String,
    benchmark::String,
    gcthreads::Int,
)
    # Read the CSV data into a DataFrame
    data = CSV.read(dataset_name(march, category), DataFrame)
    # Get the dataframe such that `file == benchmark`
    benchmark_data = filter(row -> row[:file] == benchmark, data)
    # Get all the GC times and E2E times (filter by the number of GC threads)
    gctime = benchmark_data[benchmark_data[!, :gcthreads].==gcthreads, :gc_time]
    e2etime = benchmark_data[benchmark_data[!, :gcthreads].==gcthreads, :time]
    return gctime, e2etime
end

# Build a LaTeX table for the single-threaded performance
# of 1.9 (which should be the files data/results-1.9-*.csv) and
# dev (which should be the files data/results-*.csv)
# The table should have the following format:
# | Benchmark | GC_Time at 16 GC threads / GC_Time at 1 GC thread | E2E_Time at 16 GC threads / E2E_Time at 1 GC thread |
# The corresponding LaTeX code for the table should have the form:
# \begin{table*}[t]
# \begin{tabular}{|c|c|c|}
# \hline
# Benchmark & GC Time at 16 GC threads / GC Time at 1 GC thread & E2E Time at 16 GC threads / E2E Time at 1 GC thread \\
# \hline
# ...
# \end{tabular}
# \caption{Comparison of total GC time and end-to-end time at 16 GC threads and 1 GC thread (lower is better). Results for aarch64 are shown in parentheses.}
# \end{table*}
# Note that we will be taking the geometric mean of the GC and E2E times
# accross both microarchitectures.
function build_latex_table_for_single_threaded_perf()
    categories = ["serial", "multithreaded", "slow"]
    marches = ["x86_64", "aarch64"]
    # Create a string to store the LaTeX code
    latex_table = "\\begin{table*}[t]\n\\begin{tabular}{|c|c|c|}\n\\hline\nBenchmark & \$\\frac{\\text{GC Time at 16 GC threads}}{\\text{GC Time at 1 GC thread}}\$& \$\\frac{\\text{E2E Time at 16 GC threads}}{\\text{E2E Time at 1 GC thread}}\$\\\\\n\\hline\n"
    for category in categories
        benchmarks = get_all_benchmarks_in_category(category)
        for benchmark in benchmarks
            gc_times_one_gc_thread_x86_64 = Float64[]
            e2e_times_one_gc_thread_x86_64 = Float64[]
            gc_times_sixteen_gc_threads_x86_64 = Float64[]
            e2e_times_sixteen_gc_threads_x86_64 = Float64[]
            gc_times_one_gc_thread_aarch64 = Float64[]
            e2e_times_one_gc_thread_aarch64 = Float64[]
            gc_times_sixteen_gc_threads_aarch64 = Float64[]
            e2e_times_sixteen_gc_threads_aarch64 = Float64[]
            for march in marches
                # Get the GC and E2E times for 1 GC thread
                gctime, e2etime = get_gc_and_e2e_times(march, category, benchmark, 1)
                if march == "x86_64"
                    push!(gc_times_one_gc_thread_x86_64, gctime[1])
                    push!(e2e_times_one_gc_thread_x86_64, e2etime[1])
                else
                    push!(gc_times_one_gc_thread_aarch64, gctime[1])
                    push!(e2e_times_one_gc_thread_aarch64, e2etime[1])
                end
                # Get the GC and E2E times for 16 GC threads
                gctime, e2etime = get_gc_and_e2e_times(march, category, benchmark, 16)
                if march == "x86_64"
                    push!(gc_times_sixteen_gc_threads_x86_64, gctime[1])
                    push!(e2e_times_sixteen_gc_threads_x86_64, e2etime[1])
                else
                    push!(gc_times_sixteen_gc_threads_aarch64, gctime[1])
                    push!(e2e_times_sixteen_gc_threads_aarch64, e2etime[1])
                end
            end
            # Take the mean of the GC and E2E times for 1 GC thread, each for x86_64 and aarch64
            gc_time_one_gc_thread_x86_64 = geomean(gc_times_one_gc_thread_x86_64)
            e2e_time_one_gc_thread_x86_64 = geomean(e2e_times_one_gc_thread_x86_64)
            gc_time_one_gc_thread_aarch64 = geomean(gc_times_one_gc_thread_aarch64)
            e2e_time_one_gc_thread_aarch64 = geomean(e2e_times_one_gc_thread_aarch64)
            # Take the mean of the GC and E2E times for 16 GC threads, each for x86_64 and aarch64
            gc_time_sixteen_gc_threads_x86_64 = geomean(gc_times_sixteen_gc_threads_x86_64)
            e2e_time_sixteen_gc_threads_x86_64 = geomean(e2e_times_sixteen_gc_threads_x86_64)
            gc_time_sixteen_gc_threads_aarch64 = geomean(gc_times_sixteen_gc_threads_aarch64)
            e2e_time_sixteen_gc_threads_aarch64 = geomean(e2e_times_sixteen_gc_threads_aarch64)
            # Compute the GC and E2E time ratios for x86_64
            gc_time_ratio_x86_64 = gc_time_sixteen_gc_threads_x86_64 / gc_time_one_gc_thread_x86_64
            e2e_time_ratio_x86_64 = e2e_time_sixteen_gc_threads_x86_64 / e2e_time_one_gc_thread_x86_64
            # Compute the GC and E2E time ratios for aarch64
            gc_time_ratio_aarch64 = gc_time_sixteen_gc_threads_aarch64 / gc_time_one_gc_thread_aarch64
            e2e_time_ratio_aarch64 = e2e_time_sixteen_gc_threads_aarch64 / e2e_time_one_gc_thread_aarch64
            # Truncate all the time ratios to 2 decimal places
            gc_time_ratio_x86_64 = round(gc_time_ratio_x86_64, digits = 2)
            e2e_time_ratio_x86_64 = round(e2e_time_ratio_x86_64, digits = 2)
            gc_time_ratio_aarch64 = round(gc_time_ratio_aarch64, digits = 2)
            e2e_time_ratio_aarch64 = round(e2e_time_ratio_aarch64, digits = 2)
            # Latexify the benchmark name
            benchmark = latexify_benchmark_name(benchmark)
            # Add the benchmark and the GC and E2E time ratios to the LaTeX table, don't forget the hline at the end
            latex_table *= "$benchmark & $gc_time_ratio_x86_64 ($gc_time_ratio_aarch64) & $e2e_time_ratio_x86_64 ($e2e_time_ratio_aarch64) \\\\\n\\hline\n"
        end
    end
    latex_table *= "\\end{tabular}\n\\caption{Comparison of total GC time and end-to-end time at 16 GC threads and 1 GC thread (lower is better). Results for aarch64 are shown in parentheses.}\n\\end{table*}"
    # Write the LaTeX table to a file
    open("single_threaded_perf.tex", "w") do io
        println(io, latex_table)
    end
end

function get_median_gc_times(march::String, category::String, benchmark::String)
    # Read the CSV data into a DataFrame
    data = CSV.read(dataset_name(march, category), DataFrame)
    # Get the dataframe such that `file == benchmark`
    benchmark_data = filter(row -> row[:file] == benchmark, data)
    # Get the number of all GC threads used to run the benchmark as an array
    gcthreads = unique(benchmark_data[!, :gcthreads])
    gctimes = Float64[]
    # For every number of GC threads, get the median time
    for gcthread in gcthreads
        gctime_for_gcthread =
            mean(benchmark_data[benchmark_data[!, :gcthreads].==gcthread, :gc_time])
        push!(gctimes, gctime_for_gcthread)
    end
    return gcthreads, gctimes
end

function plot_scaling()
    categories = ["serial", "multithreaded", "slow"]
    # Create a grid of 4x4 plots
    fig = Figure(resolution = (1400, 1800))
    axes = Axis[]
    for (march_idx, march) in enumerate(["x86_64", "aarch64"])
        i = 0
        for category in categories
            benchmarks = get_all_benchmarks_in_category(category)
            for benchmark in benchmarks
                i += 1
                gcthreads, gctimes = get_median_gc_times(march, category, benchmark)
                # Compute GC times speedup
                speedup = gctimes[1] ./ gctimes
                # Compute xidx, yidx in the 4x4 grid (1-indexed for both x and y)
                xidx = i % 4 == 0 ? i ÷ 4 : i ÷ 4 + 1
                yidx = i % 4 == 0 ? 4 : i % 4
                if march_idx == 1
                    ax =
                        fig[xidx, yidx] = Axis(
                            fig,
                            xlabel = "GC threads",
                            ylabel = "GC time speedup",
                            title = benchmark,
                            xscale = log2,
                            yscale = log2,
                        )
                    push!(axes, ax)
                    # Plot perfect speedup (y = x) as a gray dotted line for reference
                    lines!(
                        ax,
                        1:maximum(gcthreads),
                        1:maximum(gcthreads),
                        color = :black,
                        linestyle = :dash,
                    )
                    # Plot the speedup
                    scatterlines!(
                        ax,
                        gcthreads,
                        speedup,
                        color = :blue,
                        label = "x86_64",
                        marker = :circle,
                        markersize = 15,
                    )
                else
                    ax = fig[xidx, yidx]
                    scatterlines!(
                        ax,
                        gcthreads,
                        speedup,
                        color = :red,
                        label = "aarch64",
                        marker = :xcross,
                        markersize = 15,
                    )
                    ax = axes[i]
                    axislegend(ax, position = :lt)
                end
            end
        end
    end
    # Display the plot
    save("plot.png", fig, px_per_unit = 2)
end

function main()
    # Build the LaTeX table for single-threaded performance
    build_latex_table_for_single_threaded_perf()
    # Plot the scaling of the benchmarks
    plot_scaling()
end

main()
