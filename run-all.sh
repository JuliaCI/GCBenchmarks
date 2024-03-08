# Run serial, multithreaded and slow benchmarks

# Usage: ./run-all.sh /path/to/julia

# Get the path to the julia binary
JULIA_BIN=$1

# Benchmark settings
JULIA_NUM_BENCHMARK_RUNS=10

$JULIA_BIN --project=. -e "using Pkg; Pkg.instantiate()"

for benchmark_class in serial multithreaded slow
do
    JULIA_MUTATOR_THREADS=1
    if [ $benchmark_class == "multithreaded" ]
    then
        JULIA_MUTATOR_THREADS=16
    fi
    echo "Running $benchmark_class benchmarks"
    # Interpolate command `$JULIA_BIN --project=. run_benchmarks.jl $benchmark_class all --threads=$JULIA_MUTATOR_THREADS --gcthreads=2 --runs=$JULIA_NUM_BENCHMARK_RUNS`
    # into a variable `cmd`
    cmd=`echo $JULIA_BIN --project=. run_benchmarks.jl $benchmark_class all --threads=$JULIA_MUTATOR_THREADS --gcthreads=2 --runs=$JULIA_NUM_BENCHMARK_RUNS`
    echo "Running command: $cmd"
    $cmd
    mv results.csv results-$benchmark_class.csv
done

# Cleanup
rm results.csv

echo "Done"
