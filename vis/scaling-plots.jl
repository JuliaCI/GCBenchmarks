using CairoMakie
using CSV
using DataFrames
using Makie
using Statistics

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
    # Set the scale of the axes to log2
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
                    scatterlines!(ax, gcthreads, speedup, color = :blue, label = "x86_64", marker = :circle, markersize = 15)
                else
                    ax = fig[xidx, yidx]
                    scatterlines!(ax, gcthreads, speedup, color = :red, label = "aarch64", marker = :xcross, markersize = 15)
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
    plot_scaling()
end

main()
