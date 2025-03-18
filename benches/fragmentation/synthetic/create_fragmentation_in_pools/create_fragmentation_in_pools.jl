@static if VERSION < v"1.12.0-DEV.0"
    error("This script requires Julia 1.12 or later")
end
@static if Sys.WORD_SIZE != 64
    error("This script requires a 64-bit version of Julia")
end
@static if !Sys.isunix()
    error("This script requires a Unix-like operating system")
end
const SIZE_CLASSES_FROM_JL_STOCK_GC = vcat(
    [8],
    16:8:136,
    144:16:256,
    [
        272,
        288,
        304,
        336,
        368,
        400,
        448,
        496,
        544,
        576,
        624,
        672,
        736,
        816,
        896,
        1008,
        1088,
        1168,
        1248,
        1360,
        1488,
        1632,
        1808,
        2032,
    ],
)

# Vector of vectors... each individual vector will contain pointers to pool-allocated objects
const PTRS_TO_POOLED_OBJECTS = [Vector{Any}() for _ in SIZE_CLASSES_FROM_JL_STOCK_GC]

# We will allocate 1MB worth of objects per pool
const NUM_ALLOCATED_BYTES_PER_POOL = 1 * 1024 * 1024

# Let's create a parameterized tuple to artificially create objects of different sizes
mutable struct PooledObject{N}
    some_header::UInt64
    data::NTuple{N,UInt8}

    function PooledObject{N}() where {N}
        new{N}(0, ntuple(i -> 0, N))
    end
end

# Yeah, this is quite pedestrian, but doesn't matter for this MWE
function find_struct_param_for_size(size)
    max_n = (1 << 32) - 1
    for n = 0:max_n
        if sizeof(PooledObject{n}) == size
            return n
        end
    end
    return -1
end

function allocate_a_bunch_of_pooled_objects()
    for (i, size) in enumerate(SIZE_CLASSES_FROM_JL_STOCK_GC)
        @info "Allocating objects of size $size"
        n = find_struct_param_for_size(size)
        @info "Found struct parameter: $n"
        @assert n != -1
        nobjs = NUM_ALLOCATED_BYTES_PER_POOL / size
        for _ = 1:nobjs
            dummy_obj = PooledObject{n}()
            push!(PTRS_TO_POOLED_OBJECTS[i], dummy_obj)
        end
    end
end

function make_some_pooled_objects_unreachable()
    for (i, _) in enumerate(SIZE_CLASSES_FROM_JL_STOCK_GC)
        for (j, _) in enumerate(PTRS_TO_POOLED_OBJECTS[i])
            if j % 2 == 0
                PTRS_TO_POOLED_OBJECTS[i][j] = nothing
            end
        end
    end
end

function pretty_print_page_utilization_data()
    utilization_of_pools = Base.gc_page_utilization_data()
    for (i, _) in enumerate(SIZE_CLASSES_FROM_JL_STOCK_GC)
        @info "Pool $i: $(utilization_of_pools[i])"
    end
end

function main()
    @info "Phase 1: Allocating a bunch of pooled objects"
    allocate_a_bunch_of_pooled_objects()
    GC.gc()
    pretty_print_page_utilization_data()
    @info "Phase 2: Making some pooled objects unreachable"
    make_some_pooled_objects_unreachable()
    GC.gc()
    pretty_print_page_utilization_data()
end

main()
