include(joinpath("..", "..", "..", "utils.jl"))

module ManyRef

"""
This benchmark stresses the array handling in the GC.
We allocate a large arrays that all contain a reference to a many small objects.
The mark-queue of the GC should not overflow.
"""
function construct(array_length)
    GC.enable(false)
    arr = Array{Ref{Int}}(undef, array_length)
    for i in eachindex(arr)
        arr[i] = Ref{Int}(0)
    end
    GC.enable(true)
    GC.gc(true)
    GC.gc(true)
    Core.donotdelete(arr)
    return nothing
end

end #module

using .ManyRef

const MAX_MEMORY = round(Int, 0.8 * Sys.total_memory())
const array_length = div(MAX_MEMORY, 3*sizeof(Ptr{C_NULL}))

@info "ManyRef bench" array_length MAX_MEMORY
@gctime ManyRef.construct(array_length)
