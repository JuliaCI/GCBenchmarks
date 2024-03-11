using CSV
using DataFrames
using Statistics

const JULIA_BIN_PATH = "../julia-master/julia"
const NRUNS = 20

function main()
    # Create file for results with concurrent sweeping disabled
    open("results_concurrent_page_sweeping_disabled.csv", "w")
    # Create file for results with concurrent sweeping enabled
    open("results_concurrent_page_sweeping_enabled.csv", "w")
    # Collect the results for each benchmark
    i = 0
    for (category, benchmark) in [
        ("big_arrays", "objarray"),
        ("binary_tree", "tree_immutable"),
        ("binary_tree", "tree_mutable"),
    ]
        i += 1
        # Run the benchmarks with concurrent page sweeping disabled
        run(
            `$JULIA_BIN_PATH --project=. run_benchmarks.jl multithreaded $category $benchmark -t16 --gcthreads=16 -n$NRUNS`,
        )
        # Append to the file results_concurrent_page_sweeping_disabled.csv. Write the header only if the file is empty
        if i == 1
            run(
                pipeline(
                    `cat results.csv`,
                    `tee results_concurrent_page_sweeping_disabled.csv`,
                ),
            )
        else
            run(
                pipeline(
                    `tail -n +2 results.csv`,
                    `tee -a results_concurrent_page_sweeping_disabled.csv`,
                ),
            )
        end
        # Run the benchmarks with concurrent page sweeping enabled
        run(
            `$JULIA_BIN_PATH --project=. run_benchmarks.jl multithreaded $category $benchmark -t16 --gcthreads=16,1 -n$NRUNS`,
        )
        # Append to the file results_concurrent_page_sweeping_enabled.csv. Write the header only if the file is empty
        if i == 1
            run(
                pipeline(
                    `cat results.csv`,
                    `tee results_concurrent_page_sweeping_enabled.csv`,
                ),
            )
        else
            run(
                pipeline(
                    `tail -n +2 results.csv`,
                    `tee -a results_concurrent_page_sweeping_enabled.csv`,
                ),
            )
        end
    end
end

main()
