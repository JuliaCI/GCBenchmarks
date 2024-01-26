include(joinpath("..", "..", "..", "util", "utils.jl"))

const N = 32 * (1 << 20)
const BUBBLE_SORT_THRESHOLD = 32

using Random
Random.seed!(42)
a = rand(1:N, N)

function bubble_sort(a, start, limit)
    for i = start:limit-2
        for j = i+1:limit-1
            if a[j] < a[i]
                a[i], a[j] = a[j], a[i]
            end
        end
    end
end

function merge(src, dst, start, split, limit)
    dst_pos = start
    i = start
    j = split
    while i < split && j < limit
        if src[i] <= src[j]
            dst[dst_pos] = src[i]
            i += 1
        else
            dst[dst_pos] = src[j]
            j += 1
        end
        dst_pos += 1
    end

    while i < split
        dst[dst_pos] = src[i]
        i += 1
        dst_pos += 1
    end

    while j < limit
        dst[dst_pos] = src[j]
        j += 1
        dst_pos += 1
    end
end

function merge_sort(move, a, b, start, limit)
    if move || limit - start > BUBBLE_SORT_THRESHOLD
        split = (start + limit) ÷ 2
        r1 = Threads.@spawn merge_sort(!move, a, b, start, split)
        r2 = Threads.@spawn merge_sort(!move, a, b, split, limit)
        wait(r1)
        wait(r2)
        if move
            merge(a, b, start, split, limit)
        else
            merge(b, a, start, split, limit)
        end
    else
        bubble_sort(a, start, limit)
    end
end

function sort(a)
    b = similar(a)
    merge_sort(false, a, b, 1, length(a) + 1)
end

@gctime sort(a)
