import Glob
function rdir(dir::AbstractString, pat::Glob.FilenameMatch)
    result = String[]
    for (root, dirs, files) in walkdir(dir)
        append!(result, filter!(f -> occursin(pat, f), joinpath.(root, files)))
    end
    return result
end
rdir(dir::AbstractString, pat::AbstractString) = rdir(dir, Glob.FilenameMatch(pat))

benches = rdir("benches", "*.jl")

function find_min_size(bench_path)
    @info "Finding heap size for $bench_path"
    min_heap = 4
    max_heap = round(Int, Sys.total_memory() / 1024 / 1024)
    max_heap = min(24*1024) # 24GB is more than enough so we don't waste time
    heap_size = min_heap
    while min_heap <= max_heap
        @info "Attempting heap size" heap_size
        proc = run(pipeline(`$(Base.julia_cmd()) --heap-size-hint=$(heap_size)M $bench_path`,stdout = stdout, stderr = stderr); wait=false)
        if success(proc)
            max_heap = heap_size
            heap_size = round(Int,(max_heap + min_heap)/2)
        else
            min_heap = heap_size
            heap_size = round(Int,(max_heap + min_heap)/2)
        end
        if (max_heap - min_heap) <= 16
            break
        end
    end
    @info "Heap size for $bench_path is $heap_size"
    heap_size
end

results = [bench=>find_min_size(bench) for bench in benches]
open("min_files.txt", "w") do
    foreach(results) do pair
        write(a, first(pair))
        write(a, " $(last(pair))M\n")
    end
end