

include("../../utils.jl")

alloc(_) = Core.donotdelete(Vector{UInt8}(undef, 1<<30))

@gctime foreach(alloc, 1:10_000)


