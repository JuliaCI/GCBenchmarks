using TimeZones
using Serialization

zdts = [now(tz"UTC") for _ in  1:100_000_000];

function bench(iters)
    times = zeros(Float64, iters)
    for i in 1:iters
        times[i] = @elapsed sum(hash, ["trashfire"^min(1000, i) for i in 1:100_000])
    end
    return times
end

serialize(stdout, bench(parse(Int,ARGS[1])))
