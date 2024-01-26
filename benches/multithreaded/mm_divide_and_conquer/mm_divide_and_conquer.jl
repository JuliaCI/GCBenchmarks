include(joinpath("..", "..", "..", "util", "utils.jl"))

function matrix_multiply(res, x, y)
    i_n = size(x, 1)
    j_n = size(y, 2)
    k_n = size(y, 1)

    for i = 1:i_n
        for j = 1:j_n
            w = 0
            for k = 1:k_n
                w += x[i, k] * y[k, j]
            end
            res[i, j] = w
        end
    end
end

function matrix_multiply_recursive(res, x, y)
    i_n = size(x, 1)
    j_n = size(y, 2)
    k_n = size(y, 1)

    if i_n <= 128 || j_n <= 128 || k_n <= 128
        # Base case: use a simple matrix multiplication
        matrix_multiply(res, x, y)
    else
        # Divide matrices into submatrices
        i_half = i_n ÷ 2
        j_half = j_n ÷ 2
        k_half = k_n ÷ 2

        a11 = x[1:i_half, 1:k_half]
        a12 = x[1:i_half, (k_half+1):k_n]
        a21 = x[(i_half+1):i_n, 1:k_half]
        a22 = x[(i_half+1):i_n, (k_half+1):k_n]

        b11 = y[1:k_half, 1:j_half]
        b12 = y[1:k_half, (j_half+1):j_n]
        b21 = y[(k_half+1):k_n, 1:j_half]
        b22 = y[(k_half+1):k_n, (j_half+1):j_n]

        c11 = zeros(Int, i_half, j_half)
        c12 = zeros(Int, i_half, (j_n - j_half))
        c21 = zeros(Int, (i_n - i_half), j_half)
        c22 = zeros(Int, (i_n - i_half), (j_n - j_half))

        # Recursive matrix multiplication on submatrices
        t1 = Threads.@spawn matrix_multiply_recursive(c11, a11 + a22, b11 + b22)
        t2 = Threads.@spawn matrix_multiply_recursive(c12, a21 + a22, b11)
        t3 = Threads.@spawn matrix_multiply_recursive(c21, a11, b12 - b22)
        matrix_multiply_recursive(c22, a22, b21 - b11)

        # Wait for the spawned threads to complete
        wait(t1)
        wait(t2)
        wait(t3)

        # Combine submatrices to get the result
        res[1:i_half, 1:j_half] .= c11 .+ c12
        res[1:i_half, (j_half+1):j_n] .= c11 .+ c22
        res[(i_half+1):i_n, 1:j_half] .= c21 .+ c12
        res[(i_half+1):i_n, (j_half+1):j_n] .= c21 .+ c22
    end
end

const M_SIZE = (1 << 14)

function main_recursive()
    m1 = rand(1:100, M_SIZE, M_SIZE)
    m2 = rand(1:100, M_SIZE, M_SIZE)
    res = zeros(Int, M_SIZE, M_SIZE)

    matrix_multiply_recursive(res, m1, m2)

    return sum(res)
end

@gctime main_recursive()
