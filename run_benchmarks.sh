# !/bin/bash

JULIA_BIN=$1

# Skipping `compiler`, `framentation` and `TimeZones` due to precompilation failures.
# `rb_tree` takes too long, so I am skipping i for now as well.
OUTER_CATEGORIES_TO_SKIP=("compiler" "fragmentation")
INNER_CATEGORIES_TO_SKIP=("TimeZones" "rb_tree")

# List all subdirectories of `benches` and run benchmarks unless they are in the skip list.
for dir in benches/*/; do
    outer_category=$(basename "$dir")
    if [[ " ${OUTER_CATEGORIES_TO_SKIP[@]} " =~ " ${outer_category} " ]]; then
        echo "Skipping benchmark outer category: $outer_category"
        continue
    fi
    echo "Running benchmarks in outer category: $outer_category"
    # List all Julia files in `dir_name`
    # Julia files should have the pattern `*.jl`
    for subdir in $dir/*/; do
        for file in "$subdir"/*.jl; do
            # Extract the trailing string of `subdir` and `file`
            inner_category=$(basename "$subdir")
            if [[ " ${INNER_CATEGORIES_TO_SKIP[@]} " =~ " ${inner_category} " ]]; then
                echo "Skipping benchmark inner category: $inner_category"
                continue
            fi
            filename=$(basename "$file")
            # Remove the `.jl` extension from `filename`
            filename="${filename%.jl}"
            cmd="$JULIA_BIN --project=. run_benchmarks.jl --json $outer_category $inner_category $filename -n5"
            echo "Running benchmark with command: $cmd"
            $cmd > $filename.json
        done
    done
done

echo "All benchmarks processed."
