# simulates allocation profile of some dataframes benchmarks

using Serialization

# repeatedly append to a vector
function append_lots(N, size)
    v = Float64[]
    for i = 1:N
        append!(v,rand(size))
    end
    return v
end

function bench(iters, size=1596)
    times = zeros(Float64, iters)
    for i in 1:iters
        times[i] = @elapsed append_lots(100*1024, size)
    end
    return times
end

serialize(stdout, bench(parse(Int,ARGS[1])))
