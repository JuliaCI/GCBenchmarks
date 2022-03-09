using Cthulhu
using Serialization

module TortureTest

    # Scalability parameters - set here to roughly match the real world usecase
    # though that use case does more work.
    const NFIELDS = 888
    const NSET = 387
    const NREPS = 40

    using Random
    using Base.Meta

    struct Maybe{T}
        x::T
        is_missing::Bool
    end
    Base.convert(::Type{Maybe{T}}, x::Maybe{T}) where {T} = x
    Base.convert(::Type{Maybe{T}}, x::T) where {T} = Maybe{T}(x, true)
    Base.convert(::Type{Maybe{T}}, x) where {T} = Maybe{T}(convert(T, x), true)
    Base.eltype(::Type{Maybe{T}}) where {T} = T
    Maybe(x::T) where {T} = Maybe(x, false)

    @eval struct TestCase
        $([:($(Symbol("x$i"))::Maybe{$(rand(Bool) ? Float64 : Int64)}) for i = 1:NFIELDS]...)
    end

    @eval TestCase($(Expr(:parameters, [Expr(:kw, Symbol("x$i"), :(Maybe(convert(eltype(fieldtype(TestCase, $(quot(Symbol("x$i"))))), $(rand(Bool) ? Float64(i) : i))))) for i = 1:NFIELDS]...))) =
        TestCase($([Symbol("x$i") for i = 1:NFIELDS]...))

    @eval function run_test1(x)
        $([:(TestCase(;$([:($(Symbol("x$i")) = $(rand() < 0.05 ? (:x) : rand(Bool) ? Float64(i) : i)) for i = randperm(NFIELDS)[1:NSET]]...))) for _ = 1:NREPS]...)
    end

    @eval function run_test2(x)
        $([:(TestCase(;$([:($(Symbol("x$i")) = $(rand(Bool) ? Float64(i) : i)) for i = randperm(NFIELDS)[1:NSET]]...))) for _ = 1:NREPS]...)
    end

end

function bench(iters)
    times = zeros(Float64, iters)
    for i in 1:iters
        times[i] = @elapsed Cthulhu.mkinterp(TortureTest.run_test1, Tuple{Int});
    end
    return times
end

serialize(stdout, bench(parse(Int,ARGS[1])))
