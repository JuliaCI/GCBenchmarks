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
    -t <threads>, --threads=<threads>     Number of mutator threads to use [default: 1].
    --gcthreasds=<gcthreads>              Number of GC threads to use [default: 1].
    -s <max>, --scale=<max>               Maximum number of GC threads for scaling test.
    -h, --help                            Show this screen.
    --version                             Show version.
```

## Classes

There are three classes of benchmarks:
- *Serial* benchmarks run on a single mutator thread.
- *Multithreaded* benchmarks may run on multiple mutator threads.
- *Slow* benchmarks are long-running in comparison with the other two classes.

## Examples

- Run all serial benchmarks 5 times each using 1 mutator thread and 1 GC thread:

  `julia --project=. run_benchmarks.jl serial all -n 5`

- Run the binary tree benchmarks 10 times each with 1, 2, 4 and 8 GC threads (and 8 mutator threads):

  `julia --project=. run_benchmarks.jl multithreaded binary_tree -t 8 -s 8`

- Run the red-black tree benchmark once using 1 mutator thread and 4 GC threads:

  `julia --project=. run_benchmarks.jl slow rb_tree rb_tree -n 1 --gcthreads 4`

## The benchmarks

| Class | Category | Name | Description |
| ---   | ---      | ---  | ---         |
| Serial | TimeZones | TimeZones.jl | Creation of timezones which involve repeated short `String` allocations. |
|        | append | append.jl | Repeatedly growing `Vector`s. |
|        | bigint | pollard.jl | Tests small `BigInt`s. |
|        | linked | list.jl | Small pointer-heavy data structure. |
|        |        | tree.jl | Small pointer-heavy data structure. |
|        | strings | strings.jl | |
|        | forwarddiff | fdiff.jl| ForwardDiff matrix benchmark |
| Multithreaded | binary_tree | tree_immutable.jl | Small pointer-heavy data structure. |
|               |             | tree_mutable.jl | Small pointer-heavy data structure. |
| Slow | rb\_tree | rb\_tree.jl | Pointer graph whose minimum linear arrangement has cost Θ(n²). |
|      | pidigits.jl | Tests large `BigInt`s. |
