# Garbage Collection Test Suite

This package contains various test programs which measure the efficiency of Garbage Collection (GC) in Julia.

## QuickStart
You can run the entire benchmark suite by running `julia --project=. run_benchmarks.jl`
You can also control the number of threads and/or the number of times each benchmark is run.
For example, to run all the benchmarks 5 times with 4 threads,
`julia --project=. run_benchmarks.jl --threads=4 --runs=5`

To run a benchmark individually (eg linked/tree.jl), run 
`julia --project=. run_benchmarks.jl --bench=linked/tree.jl`
which also accepts `--threads` and `--runs`.

## The benchmarks

We expect the list of benchmarks to change over time, but for now we have the following.


### pidigits.jl
### pollard.jl
These test `BigInt` performance. `pidigits` tests large `BigInt` and `pollard` tests small `BigInt`.
### append.jl
This tests repeatedly growing `Vector`s.
### compiler_stresstest.jl
This tests some aspects of codegen, but whether it's a good GC benchmark is very version specific.
### list.jl
### tree.jl
These are tests of allocater performance for small pointer heavy data structures.
### strings.jl
### tree_immutable.jl (perfect binary tree)
### tree_mutable.jl (perfect binary tree)
These test GC performance for small pointer heavy data structures with multiple threads.
### timezones.jl
This tests the creation of timezones which involve repeated short `String` allocations.


## The results

We expect to add more results including max memory used but for now we report max, min, median end to end runtime and max, min, median gc time for each benchmark.

test = "append.jl"
run time: 193908s min, 193921s max 193915s median
gc time: 17ms min, 620ms max, 323ms median

