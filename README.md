# Garbage Collection Test Suite

This package contains various test programs which measure the efficiency of Garbage Collection (GC) in Julia.

## QuickStart
You can run the entire benchmark suite by running
julia run_benchmarks.jl <n>
Where n defaults to 10 and is the number of times to run each program.

## The benchmarks

We expect the list of benchmarks to change over time, but for now we have the following.

### append.jl
### pidigits.jl
### pollard.jl
### compiler_stresstest.jl
### list.jl
### tree.jl
### strings.jl

## The results

We expect to add more results including max memory used but for now we report max, min, median end to end runtime and max, min, median gc time for each benchmark.

