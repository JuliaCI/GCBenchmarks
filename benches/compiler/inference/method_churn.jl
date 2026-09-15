include(joinpath("..", "..", "..", "util", "utils.jl"))

# Uses the compiler itself as the GC workload: repeatedly define *fresh* methods
# (gensym'd names, so nothing is ever cached from a previous iteration) and run
# type inference + optimization over them with `code_typed`.
#
# This is the allocation profile of loading a package or a REPL session - a mix
# of Exprs, CodeInfos, IR, type objects and caches - rather than the
# uniform data structures most GC benchmarks are made of. Unlike
# inference_benchmarks.jl, which measures the *compiler's speed* on pathological
# inputs, this measures the *GC* under the compiler's allocation behaviour.

module MethodChurn

# Six leaf-body shapes exercising different parts of inference: containers,
# strings, unions, broadcasting, closures, tuples.
function leaf_body(kind::Int)
    kind == 1 && return :(begin v = [k * 0.5 for k in 1:n]; sum(sort!(v)) end)
    kind == 2 && return :(length(join(string.(1:n), ",")))
    kind == 3 && return :(begin d = Dict{Int,String}()
                                for k in 1:n; d[k] = string(k); end
                                length(d) end)
    kind == 4 && return :(begin x = n > 0 ? n : nothing
                                x === nothing ? 0 : x + 1 end)
    kind == 5 && return :(begin f = k -> k * n; sum(map(f, 1:n)) end)
    return :(begin t = (a = n, b = string(n), c = (n, n + 1))
                   t.a + t.c[2] + length(t.b) end)
end

# One "unit" is a call tree of nine fresh methods: six leaves, two mids that
# call three leaves each, and a top that calls both mids in a loop. Inferring
# the top infers the whole fresh graph.
function define_unit()
    leaves = [gensym(:leaf) for _ in 1:6]
    mids = [gensym(:mid) for _ in 1:2]
    top = gensym(:top)
    defs = Expr(:block)
    for (j, f) in enumerate(leaves)
        push!(defs.args, :(function $f(n::Int); $(leaf_body(j)); end))
    end
    for (j, m) in enumerate(mids)
        l1, l2, l3 = leaves[3j-2], leaves[3j-1], leaves[3j]
        push!(defs.args, :(function $m(n::Int)
            $l1(n) + $l2(n) + Int($l3(n) % 1000)
        end))
    end
    push!(defs.args, :(function $top(n::Int)
        s = 0
        for i in 1:n
            s += $(mids[1])(i) + $(mids[2])(i)
        end
        return s
    end))
    Core.eval(@__MODULE__, defs)
    return top
end

const UNITS_PER_ITER = 40
const NITER = 5

function churn()
    inferred = 0
    for _ in 1:NITER
        for _ in 1:UNITS_PER_ITER
            top = define_unit()
            # the binding was created after this method's world: look it up and
            # infer it in the latest world
            f = Base.invokelatest(getglobal, @__MODULE__, top)
            ci = Base.invokelatest(code_typed, f, (Int,))
            inferred += length(ci)
        end
    end
    return inferred
end

end # module MethodChurn

# compile the reflection machinery outside the measured region
MethodChurn.define_unit()
code_typed(sin, (Float64,))

@gctime MethodChurn.churn()
