import Glob
function rdir(dir::AbstractString, pat::Glob.FilenameMatch)
    result = String[]
    for (root, _, files) in walkdir(dir)
        append!(result, filter!(f -> occursin(pat, f), joinpath.(root, files)))
    end
    return result
end
rdir(dir::AbstractString, pat::AbstractString) = rdir(dir, Glob.FilenameMatch(pat))

benches = rdir("benches", "*.jl")

function find_min_size(bench_path)
    @info "Finding heap size for $bench_path"
    bench_path_parent = dirname(bench_path)
    min_heap = 4
    max_heap = min(24 * 1024) # 24GB is more than enough so we don't waste time
    heap_size = min_heap
    while min_heap <= max_heap
        @info "Attempting heap size $(heap_size)MB"
        proc = run(
            pipeline(
                `$(Base.julia_cmd()) --project=$(bench_path_parent) --heap-size-hint=$(heap_size)M $bench_path`,
                stdout = stdout,
                stderr = stderr,
            );
            wait = false,
        )
        if success(proc)
            max_heap = heap_size
            heap_size = round(Int, (max_heap + min_heap) / 2)
        else
            min_heap = heap_size
            heap_size = round(Int, (max_heap + min_heap) / 2)
        end
        if (max_heap - min_heap) <= 16
            break
        end
    end
    @info "Heap size for $bench_path is $(heap_size)MB"
    heap_size
end

results = [bench => find_min_size(bench) for bench in benches]
open("heap_sizes.csv", "w") do io
    println(io, "bench,heap_size")
    for (bench, heap_size) in results
        println(io, "$bench,$heap_size")
    end
end
