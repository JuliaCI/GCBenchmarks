include(joinpath("..", "..", "..", "util", "utils.jl"))

# Port of Go's `garbage` benchmark (golang/benchmarks/garbage), the GC-heavy
# workload used to motivate the Green Tea collector.
#
# The original repeatedly parses net/http with go/parser and discards the result,
# keeping an array of parsed ASTs alive and overwriting only the first half each
# iteration, so the second half behaves as an old generation. Parsing is done by
# 2*GOMAXPROCS concurrent workers.
#
# This version parses Julia source from Base with `Meta.parseall`. An AST is a
# deep, pointer-rich graph of many *different* small types (Expr, Symbol,
# LineNumberNode, Vector{Any}, literals), which makes this a heterogeneous-heap
# stress test for the mark phase - unlike the binary-tree benchmarks, no two
# neighbouring objects can be assumed to share a layout.

module ASTChurn

const SRC_NAMES = ("abstractarray.jl", "array.jl", "dict.jl", "strings/basic.jl",
                   "regex.jl", "iterators.jl", "set.jl", "sort.jl", "show.jl",
                   "reduce.jl")

function load_source()
    io = IOBuffer()
    for name in SRC_NAMES
        path = Base.find_source_file(name)
        (path === nothing || !isfile(path)) && continue
        write(io, read(path, String), "\n")
    end
    s = String(take!(io))
    isempty(s) && error("no Julia source found to parse")
    return s
end

const SRC = load_source()

parse_package() = Meta.parseall(SRC)

# Total parses and the size of the live window. The window is deliberately a
# fixed count rather than derived from a heap-size measurement: deriving it made
# the live heap differ between runs, which made mark times incomparable.
const NITER = 200
const NPKG = 64

function churn()
    parsed = Vector{Any}(undef, NPKG)
    for i in 1:NPKG                          # warm up, and populate the live set
        parsed[i] = parse_package()
    end
    GC.gc(true)

    half = max(NPKG ÷ 2, 1)
    pos = Threads.Atomic{Int}(0)
    remain = Threads.Atomic{Int}(NITER)
    lk = ReentrantLock()

    # 2 * nthreads concurrent parsers, as in the Go version
    tasks = map(1:(2 * Threads.nthreads())) do _
        Threads.@spawn while Threads.atomic_sub!(remain, 1) > 0
            p = parse_package()
            # Overwrite only the first half; the rest stays as the old generation
            i = Threads.atomic_add!(pos, 1)
            @lock lk begin
                parsed[i % half + 1] = p
            end
        end
    end
    foreach(wait, tasks)
    return pos[]
end

end # module ASTChurn

@gctime ASTChurn.churn()
