include(joinpath("..", "..", "..", "util", "utils.jl"))

# A loopback HTTP server under load, as a GC benchmark.
#
# Server workloads are the motivating case for concurrent-GC work (Go's garbage
# benchmark and Green Tea were both driven by them): many tasks, a high rate of
# short-lived request/response garbage (strings, buffers, headers), and a
# long-lived response cache behind it acting as an old generation. None of the
# existing benchmarks has this profile - task-heavy, IO-bound, heterogeneous.
#
# The server and the clients run in the same process, 4 client tasks per thread,
# over 127.0.0.1.

module WebServerBench

using HTTP
using Sockets

const NREQ = 8000        # total requests
const CACHE_SIZE = 512   # responses kept alive server-side (the old generation)

# Build a JSON-ish payload of nested Dicts/Vectors, then render it. The returned
# pair is (retained object graph, response body).
function build_item(id::Int)
    item = Dict{String,Any}(
        "id" => id,
        "name" => "item-$id",
        "tags" => [string("tag", (id + k) % 37) for k in 1:8],
        "attrs" => Dict{String,Any}(string("k", k) => id * k for k in 1:12),
        "history" => [(seq = k, note = "rev $k of $id") for k in 1:6],
    )
    io = IOBuffer()
    show(io, item)
    return item, String(take!(io))
end

function serve_and_hammer(nreq::Int = NREQ)
    cache = Vector{Any}(undef, CACHE_SIZE)
    fill!(cache, nothing)
    lk = ReentrantLock()

    function handler(req::HTTP.Request)
        id = parse(Int, last(split(req.target, '/')))
        item, body = build_item(id)
        @lock lk begin
            cache[id % CACHE_SIZE + 1] = item
        end
        return HTTP.Response(200, ["Content-Type" => "application/json"], body)
    end

    port, sock = Sockets.listenany(ip"127.0.0.1", 8797)
    server = HTTP.serve!(handler, "127.0.0.1", port; server = sock)

    nbytes = Threads.Atomic{Int}(0)
    next = Threads.Atomic{Int}(0)
    try
        tasks = map(1:(4 * Threads.nthreads())) do _
            Threads.@spawn begin
                got = 0
                while true
                    i = Threads.atomic_add!(next, 1)
                    i >= nreq && break
                    resp = HTTP.get("http://127.0.0.1:$port/item/$i";
                                    retry = false, status_exception = true)
                    got += length(resp.body)
                end
                Threads.atomic_add!(nbytes, got)
            end
        end
        foreach(wait, tasks)
    finally
        close(server)
    end
    return nbytes[]
end

end # module WebServerBench

# compile server + client paths outside the measured region
WebServerBench.serve_and_hammer(32)

@gctime WebServerBench.serve_and_hammer()
