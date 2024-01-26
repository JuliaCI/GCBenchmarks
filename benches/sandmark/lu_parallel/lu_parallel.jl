include(joinpath("..", "..", "..", "utils.jl"))

const NUM_DOMAINS = 32
const MAT_SIZE = 2048

using Random
const RNG = Random.MersenneTwister(1234)
Random.seed!(RNG)

function create(f)
    fa = zeros(Float64, MAT_SIZE, MAT_SIZE)
    for i = 1:MAT_SIZE
        for j = 1:MAT_SIZE
            fa[i, j] = f(i, j)
        end
    end
    return fa
end

function parallel_create(f)
    fa = zeros(Float64, MAT_SIZE, MAT_SIZE)
    Threads.@threads for i = 1:MAT_SIZE
        for j = 1:MAT_SIZE
            fa[i, j] = f(i, j)
        end
    end
    return fa
end

get(m, r, c) = m[r, c]
set(m, r, c, v) = (m[r, c] = v)

function parallel_copy(a)
    n = size(a, 1)
    b = zeros(Float64, n, n)
    Threads.@threads for i = 1:NUM_DOMAINS
        copy_part(a, b, i)
    end
    return b
end

function copy_part(a, b, i)
    s = (i - 1) * size(a, 1) ÷ NUM_DOMAINS + 1
    e = i * size(a, 1) ÷ NUM_DOMAINS
    b[s:e, :] .= a[s:e, :]
end

function lup(a0)
    a = parallel_copy(a0)
    Threads.@threads for k = 1:MAT_SIZE-1
        for row = k+1:MAT_SIZE
            factor = a[row, k] / a[k, k]
            for col = k+1:MAT_SIZE
                a[row, col] -= factor * a[k, col]
            end
            a[row, k] = factor
        end
    end
    return a
end

function main()
    a = parallel_create((i, j) -> rand(Float64) * 100.0 + 1.0)
    lu = lup(a)
    _l = parallel_create((i, j) -> if i > j
        lu[i, j]
    elseif i == j
        1.0
    else
        0.0
    end)
    _u = parallel_create((i, j) -> if i ≤ j
        lu[i, j]
    else
        0.0
    end)
    return sum(_l) + sum(_u)
end

@gctime main()
