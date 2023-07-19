include(joinpath("..", "..", "..", "utils.jl"))

using LinearAlgebra, Statistics, ForwardDiff

const BENCH_OPNORMS = (66.0, 33.0, 22.0, 11.0, 6.0, 3.0, 2.0, 0.5, 0.03, 0.001)

"""
Generates one random matrix per opnorm.
All generated matrices are scale multiples of one another.
This is meant to exercise all code http://localhost:55600/ui/flamegraphpaths in the `expm` function.
"""
function randmatrices(n)
    A = randn(n, n)
    op = opnorm(A, 1)
    map(BENCH_OPNORMS) do x
        (x / op) .* A
    end
end

function _matevalpoly!(B, C, D, A::AbstractMatrix{T}, t::NTuple{1}) where {T}
    M = size(A, 1)
    te = T(last(t))
    @inbounds for n = 1:M, m = 1:M
        B[m, n] = ifelse(m == n, te, zero(te))
    end
    @inbounds for n = 1:M, k = 1:M, m = 1:M
        B[m, n] = muladd(A[m, k], D[k, n], B[m, n])
    end
    return B
end
function _matevalpoly!(B, C, D, A::AbstractMatrix{T}, t::NTuple) where {T}
    M = size(A, 1)
    te = T(last(t))
    @inbounds for n = 1:M, m = 1:M
        C[m, n] = ifelse(m == n, te, zero(te))
    end
    @inbounds for n = 1:M, k = 1:M, m = 1:M
        C[m, n] = muladd(A[m, k], D[k, n], C[m, n])
    end
    _matevalpoly!(B, D, C, A, Base.front(t))
end
function matevalpoly!(B, C, D, A::AbstractMatrix{T}, t::NTuple) where {T}
    t1 = Base.front(t)
    te = T(last(t))
    tp = T(last(t1))
    @inbounds for j in axes(A, 2), i in axes(A, 1)
        D[i, j] = muladd(A[i, j], te, ifelse(i == j, tp, zero(tp)))
    end
    _matevalpoly!(B, C, D, A, Base.front(t1))
end
function matevalpoly!(B, C, D, A::AbstractMatrix{T}, t::NTuple{2}) where {T}
    t1 = Base.front(t)
    te = T(last(t))
    tp = T(last(t1))
    @inbounds for j in axes(A, 2), i in axes(A, 1)
        B[i, j] = muladd(A[i, j], te, ifelse(i == j, tp, zero(tp)))
    end
    return B
end
ceillog2(x::Float64) =
    (reinterpret(Int, x) - 1) >> Base.significand_bits(Float64) - 1022

naive_matmul!(C, A, B) = @inbounds for n in axes(C, 2), m in axes(C, 1)
    Cmn = zero(eltype(C))
    for k in axes(A, 2)
        Cmn = muladd(A[m, k], B[k, n], Cmn)
    end
    C[m, n] = Cmn
end
naive_matmuladd!(C, A, B) = @inbounds for n in axes(C, 2), m in axes(C, 1)
    Cmn = zero(eltype(C))
    for k in axes(A, 2)
        Cmn = muladd(A[m, k], B[k, n], Cmn)
    end
    C[m, n] += Cmn
end
_deval(x) = x
_deval(x::ForwardDiff.Dual) = _deval(ForwardDiff.value(x))

function opnorm1(A)
    n = _deval(zero(eltype(A)))
    @inbounds for j in axes(A, 2)
        s = _deval(zero(eltype(A)))
        @fastmath for i in axes(A, 1)
            s += abs(_deval(A[i, j]))
        end
        n = max(n, s)
    end
    return n
end

function expm!(
    Z::AbstractMatrix,
    A::AbstractMatrix,
    (matmul!)=naive_matmul!,
    (matmuladd!)=naive_matmuladd!
)
    # omitted: matrix balancing, i.e., LAPACK.gebal!
    # nA = maximum(sum(abs.(A); dims=Val(1)))    # marginally more performant than norm(A, 1)
    nA = opnorm1(A)
    N = LinearAlgebra.checksquare(A)
    # B and C are temporaries
    ## For sufficiently small nA, use lower order Padé-Approximations
    A2 = similar(A)
    matmul!(A2, A, A)
    if nA <= 2.1
        U = Z
        V = similar(A)
        if nA <= 0.015
            matevalpoly!(V, nothing, nothing, A2, (60, 1))
            matmul!(U, A, V)
            matevalpoly!(V, nothing, nothing, A2, (120, 12))
        else
            B = similar(A)
            if nA <= 0.25
                matevalpoly!(V, nothing, U, A2, (15120, 420, 1))
                matmul!(U, A, V)
                matevalpoly!(V, nothing, B, A2, (30240, 3360, 30))
            else
                C = similar(A)
                if nA <= 0.95
                    matevalpoly!(V, C, U, A2, (8648640, 277200, 1512, 1))
                    matmul!(U, A, V)
                    matevalpoly!(V, B, C, A2, (17297280, 1995840, 25200, 56))
                else
                    matevalpoly!(V, C, U, A2, (8821612800, 302702400, 2162160, 3960, 1))
                    matmul!(U, A, V)
                    matevalpoly!(
                        V,
                        B,
                        C,
                        A2,
                        (17643225600, 2075673600, 30270240, 110880, 90)
                    )
                end
            end
        end
        @inbounds for m = 1:N*N
            u = U[m]
            v = V[m]
            U[m] = v + u
            V[m] = v - u
        end
        ldiv!(lu!(V), U)
        expA = U
        # expA = (V - U) \ (V + U)
    else
        si = ceillog2(nA / 5.4)               # power of 2 later reversed by squaring
        if si > 0
            A = A / exp2(si)
        end
        A4 = similar(A)
        A6 = similar(A)
        matmul!(A4, A2, A2)
        matmul!(A6, A2, A4)

        U = Z
        B = zero(A)
        @inbounds for m = 1:N
            B[m, m] = 32382376266240000
        end
        @inbounds for m = 1:N*N
            a6 = A6[m]
            a4 = A4[m]
            a2 = A2[m]
            B[m] = muladd(
                33522128640,
                a6,
                muladd(10559470521600, a4, muladd(1187353796428800, a2, B[m]))
            )
            U[m] = muladd(16380, a4, muladd(40840800, a2, a6))
        end
        matmuladd!(B, A6, U)
        matmul!(U, A, B)

        V = si > 0 ? fill!(A, 0) : zero(A)
        @inbounds for m = 1:N
            V[m, m] = 64764752532480000
        end
        @inbounds for m = 1:N*N
            a6 = A6[m]
            a4 = A4[m]
            a2 = A2[m]
            B[m] = muladd(182, a6, muladd(960960, a4, 1323241920 * a2))
            V[m] = muladd(
                670442572800,
                a6,
                muladd(129060195264000, a4, muladd(7771770303897600, a2, V[m]))
            )
        end
        matmuladd!(V, A6, B)

        @inbounds for m = 1:N*N
            u = U[m]
            v = V[m]
            U[m] = v + u
            V[m] = v - u
        end
        ldiv!(lu!(V), U)
        expA = U
        # expA = (V - U) \ (V + U)

        if si > 0            # squaring to reverse dividing by power of 2
            for _ = 1:si
                matmul!(V, expA, expA)
                expA, V = V, expA
            end
            if Z !== expA
                copyto!(Z, expA)
                expA = Z
            end
        end
    end
    expA
end
expm_bad!(Z, A) = expm!(Z, A, mul!, (C, A, B) -> mul!(C, A, B, 1.0, 1.0))

d(x, n) = ForwardDiff.Dual(x, ntuple(_ -> randn(), n))
function dualify(A, n, j)
    if n > 0
        A = d.(A, n)
        if (j > 0)
            A = d.(A, j)
        end
    end
    A
end
struct ForEach{A,B,F}
    f::F
    a::A
    b::B
end
ForEach(f, b) = ForEach(f, nothing, b)
(f::ForEach)() = foreach(Base.Fix1(f.f, f.a), f.b)
(f::ForEach{Nothing})() = foreach(f.f, f.b)

l = 2;
j = 2;
n = 7;
const As = map(x -> dualify(x, n, j), randmatrices(l));
const B = similar(As[1]);

function foo()
    for i in 1:400000
        ForEach(expm_bad!, B, As)()
    end
end

@gc_time foo()
