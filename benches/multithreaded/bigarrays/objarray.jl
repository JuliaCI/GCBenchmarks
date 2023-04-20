include(joinpath("..", "..", "..", "utils.jl"))

using Random: seed!
seed!(1)

abstract type Cell end

struct CellA<:Cell
    a::Ref{Int}
end

struct CellB<:Cell
    b::String
end

function fillcells!(mc::Array{Cell})
    for ind in eachindex(mc)
        mc[ind] = ifelse(rand() > 0.5, CellA(ind), CellB(string(ind)))
    end
    return mc
end

function work(size)
    mcells = Array{Cell}(undef, size, size)
    mc = fillcells!(mcells)
end

function run(maxsize)
    Threads.@threads for i in 1:maxsize
        work(i*1000)
    end
end

@gctime run(8)