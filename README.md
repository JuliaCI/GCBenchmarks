# Garbage Collection Test Suite

This package contains various test programs which measure the efficiency of Garbage Collection (GC) in Julia.

## QuickStart
You can run the entire benchmark suite by running
julia run_benchmarks.jl <n>
Where n defaults to 10 and is the number of times to run each program.

You can run each benchmark individually by running
julia run_one_benchmark.jl benches/linked/tree.jl <n>


## The benchmarks

We expect the list of benchmarks to change over time, but for now we have the following.

### append.jl
### pidigits.jl
### pollard.jl
### compiler_stresstest.jl
### list.jl
### tree.jl
### strings.jl
### tree_immutable.jl (perfect binary tree)
### tree_mutable.jl (perfect binary tree)

## The results

We expect to add more results including max memory used but for now we report max, min, median end to end runtime and max, min, median gc time for each benchmark.

test = "append.jl"
run time: 193908s min, 193921s max 193915s median
gc time: 17ms min, 620ms max, 323ms median

