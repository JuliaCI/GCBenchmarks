include("../../utils.jl")

# simulates allocation profile of some dataframes benchmarks
# by repeatedly append to a vector
function append_lots(iters=100*1024, size=1596)
    v = Float64[]
    for i = 1:iters
        append!(v,rand(size))
    end
    return v
end

n::Int = parse(Int,ARGS[1])
@gctime n append_lots()
