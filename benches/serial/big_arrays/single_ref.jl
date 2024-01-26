include(joinpath("..", "..", "..", "utils.jl"))

module SingleRef

"""
This benchmark stresses the array handling in the GC.
We allocate a large arrays that all contain a reference to a singular object.
The mark-queue of the GC should not overflow.
"""
function construct(array_length)
    obj = Ref{Int}(0)
    arr = Array{Ref{Int}}(undef, array_length)
    fill!(arr, obj)
    GC.gc(true)
    GC.gc(true)
    Core.donotdelete(arr)
    return nothing
end

end #module

using .SingleRef

const GB = 1<<30
const MAX_MEMORY = round(Int, 0.8 * GB)
const array_length = div(MAX_MEMORY, sizeof(Ptr{C_NULL}))

@gctime SingleRef.construct(array_length)
