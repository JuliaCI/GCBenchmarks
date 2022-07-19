# Garbage Collection Test Suite

This package contains various test programs which measure the efficiency of Garbage
Collection (GC) in Julia.

## Running

```
Usage:
    run_benchmarks.jl (serial|multithreaded|slow) (all|<category> [<name>]) [options]
    run_benchmarks.jl -h | --help
    run_benchmarks.jl --version
Options:
    -n <runs>, --runs=<runs>              Number of runs for each benchmark [default: 10].
    -t <threads>, --threads=<threads>     Number of threads to use [default: 1].
    -s <max>, --scale=<max>               Maximum number of threads for scaling test.
    -h, --help                            Show this screen.
    --version                             Show version.
```

## Classes

There are three classes of benchmarks:
- *Serial* benchmarks do not use threads. The `--threads` and `--scale` options are only
  useful if testing multithreaded GC.
- *Multithreaded* benchmarks do use threads.
- *Slow* benchmarks are long-running in comparison with the other two classes.

## Examples

- Run all serial benchmarks 5 times each using 1 thread:

  `julia --project=. run_benchmarks.jl serial all -n 5`

- Run the binary tree benchmarks 10 times each with 1, 2, 4 and 8 threads:

  `julia --project=. run_benchmarks.jl multithreaded binary_tree -s 8`

- Run the red-black tree benchmark once using 1 thread:

  `julia --project=. run_benchmarks.jl slow rb_tree rb_tree -n 1`

## The benchmarks

| Class | Category | Name | Description |
| ---   | ---      | ---  | ---         |
| Serial | TimeZones | TimeZones.jl | Creation of timezones which involve repeated short `String` allocations. |
|        | append | append.jl | Repeatedly growing `Vector`s. |
|        | bigint | pidigits.jl | Tests large `BigInt`s. |
|        |        | pollard.jl | Tests small `BigInt`s. |
|        | linked | list.jl | Small pointer-heavy data structure. |
|        |        | tree.jl | Small pointer-heavy data structure. |
|        | strings | strings.jl | |
| Multithreaded | binary_tree | tree_immutable.jl | Small pointer-heavy data structure. |
|               |             | tree_mutable.jl | Small pointer-heavy data structure. |
|               | flux | flux_multithreaded_training.jl | |
|               | ttsp | ttsp.jl | Time-to-safepoint. |
| Slow | rb\_tree | rb\_tree.jl | Pointer graph whose minimum linear arrangement has cost Θ(n²). |
|      | diffeq | ensemblesolve.jl | |
