include(joinpath("..", "..", "..", "util", "utils.jl"))

# InferenceBenchmarks taken from BaseBenchmarks.jl (https://github.com/JuliaCI/BaseBenchmarks.jl)

module InferenceBenchmarks

# InferenceBenchmarker
# ====================
# this new `AbstractInterpreter` satisfies the minimum interface requirements and manages
# its cache independently in a way it is totally separated from the native code cache
# managed by the runtime system: this allows us to profile Julia-level inference reliably
# without being influenced by previous trials or some native execution

@static if VERSION ≥ v"1.12.0-DEV.1581"
if Base.REFLECTION_COMPILER[] === nothing
const CC = Base.Compiler
else
const CC = Base.REFLECTION_COMPILER[]
end
else
const CC = Core.Compiler
end

using Core:
    MethodInstance, CodeInstance, MethodTable, SimpleVector
using .CC:
    AbstractInterpreter, InferenceParams, InferenceResult, InferenceState,
    OptimizationParams, OptimizationState, WorldRange, WorldView,
    specialize_method, unwrap_unionall, rewrap_unionall, copy
@static if VERSION ≥ v"1.11.0-DEV.1498"
    import .CC: get_inference_world
else
    import .CC: get_world_counter as get_inference_world
end
using Base: get_world_counter
using InteractiveUtils: gen_call_with_extracted_types_and_kwargs
using BenchmarkTools: @benchmarkable, BenchmarkGroup, addgroup!

struct InferenceBenchmarkerCache
    dict::IdDict{MethodInstance,CodeInstance}
    InferenceBenchmarkerCache() = new(IdDict{MethodInstance,CodeInstance}())
end
struct InferenceBenchmarker <: AbstractInterpreter
    world::UInt
    inf_params::InferenceParams
    opt_params::OptimizationParams
    optimize::Bool
    compress::Bool
    discard_trees::Bool
    inf_cache::Vector{InferenceResult}
    code_cache::InferenceBenchmarkerCache
    function InferenceBenchmarker(
        world::UInt = get_world_counter();
        inf_params::InferenceParams = InferenceParams(),
        opt_params::OptimizationParams = OptimizationParams(),
        optimize::Bool = true,
        compress::Bool = true,
        discard_trees::Bool = true,
        inf_cache::Vector{InferenceResult} = InferenceResult[],
        code_cache::InferenceBenchmarkerCache = InferenceBenchmarkerCache())
        return new(
            world,
            inf_params,
            opt_params,
            optimize,
            compress,
            discard_trees,
            inf_cache,
            code_cache)
    end
end

CC.may_optimize(interp::InferenceBenchmarker) = interp.optimize
CC.may_compress(interp::InferenceBenchmarker) = interp.compress
CC.may_discard_trees(interp::InferenceBenchmarker) = interp.discard_trees
CC.InferenceParams(interp::InferenceBenchmarker) = interp.inf_params
CC.OptimizationParams(interp::InferenceBenchmarker) = interp.opt_params
#=CC.=#get_inference_world(interp::InferenceBenchmarker) = interp.world
CC.get_inference_cache(interp::InferenceBenchmarker) = interp.inf_cache
CC.code_cache(interp::InferenceBenchmarker) = WorldView(interp.code_cache, WorldRange(get_inference_world(interp)))
CC.get(wvc::WorldView{InferenceBenchmarkerCache}, mi::MethodInstance, default) = get(wvc.cache.dict, mi, default)
CC.getindex(wvc::WorldView{InferenceBenchmarkerCache}, mi::MethodInstance) = getindex(wvc.cache.dict, mi)
CC.haskey(wvc::WorldView{InferenceBenchmarkerCache}, mi::MethodInstance) = haskey(wvc.cache.dict, mi)
CC.setindex!(wvc::WorldView{InferenceBenchmarkerCache}, ci::CodeInstance, mi::MethodInstance) = setindex!(wvc.cache.dict, ci, mi)
@static if isdefined(CC, :cache_owner)
CC.cache_owner(wvc::InferenceBenchmarker) = wvc.code_cache
end

function inf_gf_by_type!(interp::InferenceBenchmarker, @nospecialize(tt::Type{<:Tuple}); kwargs...)
    match = Base._which(tt; world=get_inference_world(interp))
    return inf_method_signature!(interp, match.method, match.spec_types, match.sparams; kwargs...)
end

inf_method!(interp::InferenceBenchmarker, m::Method; kwargs...) =
    inf_method_signature!(interp, m, m.sig, method_sparams(m); kwargs...)
function method_sparams(m::Method)
    s = TypeVar[]
    sig = m.sig
    while isa(sig, UnionAll)
        push!(s, sig.var)
        sig = sig.body
    end
    return svec(s...)
end
inf_method_signature!(interp::InferenceBenchmarker, m::Method, @nospecialize(atype), sparams::SimpleVector; kwargs...) =
    inf_method_instance!(interp, specialize_method(m, atype, sparams)::MethodInstance; kwargs...)

function inf_method_instance!(interp::InferenceBenchmarker, mi::MethodInstance;
                              run_optimizer::Bool = true)
    result = InferenceResult(mi)
    frame = InferenceState(result, #=cache_mode=#run_optimizer ? :global : :no, interp)::InferenceState
    CC.typeinf(interp, frame)
    return frame
end

macro inf_call(ex0...)
    return gen_call_with_extracted_types_and_kwargs(__module__, :inf_call, ex0)
end
function inf_call(@nospecialize(f), @nospecialize(types = Base.default_tt(f));
                  interp::InferenceBenchmarker = InferenceBenchmarker(),
                  run_optimizer::Bool = true)
    ft = Core.Typeof(f)
    if isa(types, Type)
        u = unwrap_unionall(types)
        tt = rewrap_unionall(Tuple{ft, u.parameters...}, types)
    else
        tt = Tuple{ft, types...}
    end
    frame = inf_gf_by_type!(interp, tt; run_optimizer)
    frame.bestguess !== Union{} || error("invalid inference benchmark found")
    return frame
end

macro abs_call(ex0...)
    return gen_call_with_extracted_types_and_kwargs(__module__, :abs_call, ex0)
end
function abs_call(@nospecialize(f), @nospecialize(types = Base.default_tt(f));
                  interp::InferenceBenchmarker = InferenceBenchmarker(; optimize = false))
    return inf_call(f, types; interp)
end

macro opt_call(ex0...)
    return gen_call_with_extracted_types_and_kwargs(__module__, :opt_call, ex0)
end
function opt_call(@nospecialize(f), @nospecialize(types = Base.default_tt(f));
                  interp::InferenceBenchmarker = InferenceBenchmarker())
    frame = inf_call(f, types; interp, run_optimizer = false)
    evals = 0
    return function ()
        @assert (evals += 1) <= 1
        # # `optimize` may modify these objects, so need to stash the pre-optimization states, if we want to allow multiple evals
        # src, stmt_info, slottypes, ssavalue_uses = copy(frame.src), copy(frame.stmt_info), copy(frame.slottypes), copy(frame.ssavalue_uses)
        # cfg = copy(frame.cfg)
        # unreachable = @static hasfield(InferenceState, :unreachable) ? copy(frame.unreachable) : nothing
        # bb_vartables = @static hasfield(InferenceState, :bb_vartables) ? copy(frame.bb_vartables) : nothing
        opt = OptimizationState(frame, interp)
        CC.optimize(interp, opt, frame.result)
        # frame.src, frame.stmt_info, frame.slottypes, frame.ssavalue_uses = src, stmt_info, slottypes, ssavalue_uses
        # cfg === nothing || (frame.cfg = cfg)
        # unreachable === nothing || (frame.unreachable = unreachable)
        # bb_vartables === nothing || (frame.bb_vartables = bb_vartables)
    end
end

function tune_benchmarks!(
    g::BenchmarkGroup;
    seconds=30,
    gcsample=true,
    )
    for v in values(g)
        v.params.seconds = seconds
        v.params.gcsample = gcsample
        v.params.evals = 1 # `setup` must be functional
    end
end

# "inference" benchmark targets
# =============================

# TODO add TTFP?
# XXX some targets below really depends on the compiler implementation itself
# (e.g. `abstract_call_gf_by_type`) and thus a bit more unreliable --  ideally
# we want to replace them with other functions that have the similar characteristics
# but whose call graph are orthogonal to the Julia's compiler implementation

using REPL.REPLCompletions: completions
broadcasting(xs, x) = findall(>(x), abs.(xs))
let # check the compilation behavior for a function with lots of local variables
    # (where the sparse state management is critical to get a reasonable performance)
    # see https://github.com/JuliaLang/julia/pull/45276
    n = 10000
    ex = Expr(:block)
    var = gensym()
    push!(ex.args, :($var = x))
    for _ = 1:n
        newvar = gensym()
        push!(ex.args, :($newvar = $var + 1))
        var = newvar
    end
    @eval global function many_local_vars(x)
        $ex
    end
end
let # benchmark the performance benefit of `CachedMethodTable`
    # see https://github.com/JuliaLang/julia/pull/46535
    n = 100
    ex = Expr(:block)
    var = gensym()
    push!(ex.args, :(y = sum(x)))
    for i = 1:n
        push!(ex.args, :(x .= $(Float64(i))))
        push!(ex.args, :(y += sum(x)))
    end
    push!(ex.args, :(return y))
    @eval global function many_method_matches(x)
        $ex
    end
end
let # check the performance benefit of concrete evaluation
    param = 1000
    ex = Expr(:block)
    var = gensym()
    push!(ex.args, :($var = x))
    for _ = 1:param
        newvar = gensym()
        push!(ex.args, :($newvar = sin($var)))
        var = newvar
    end
    @eval let
        sins(x) = $ex
        global many_const_calls() = sins(42)
    end
end
# check the performance benefit of caching `GlobalRef`-lookup result
# see https://github.com/JuliaLang/julia/pull/46729
using Core.Intrinsics: add_int
const ONE = 1
@eval function many_global_refs(x)
    z = 0
    $([:(z = add_int(x, add_int(z, ONE))) for _ = 1:10000]...)
    return add_int(z, ONE)
end
strangesum(::Vector{Float64}) = error("this should not be called")
strangesum(x::AbstractArray) = sum(x)
let # check performance of invoke call handling
    n = 100
    ex = Expr(:block)
    var = gensym()
    push!(ex.args, :(y = sum(x)))
    for i = 1:n
        push!(ex.args, :(y += Base.@invoke strangesum(x::AbstractArray)))
    end
    push!(ex.args, :(return y))
    @eval global function many_invoke_calls(x)
        $ex
    end
end
import Base.Experimental: @opaque
let # check performance of opaque closure handling
    n = 100
    ex = Expr(:block)
    var = gensym()
    push!(ex.args, :(y = sum(x)))
    for i = 1:n
        push!(ex.args, :(oc = @inline @opaque (i, x, y) -> begin
            x .= Float64(i)
            y += sum(x)
        end))
        push!(ex.args, :(oc($i, x, y)))
    end
    push!(ex.args, :(return y))
    @eval global function many_opaque_closures(x)
        $ex
    end
end


function run_all_benchmarks()
    # abstract interpretation
    @abs_call sin(42)
    @abs_call rand(Float64)
    abs_call(println, (QuoteNode,))
    abs_call(broadcasting, (Vector{Float64},Float64))
    abs_call(completions, (String,Int))
    abs_call(Base.init_stdio, (Ptr{Cvoid},))
    abs_call(many_local_vars, (Int,))
    abs_call(many_method_matches, (Vector{Float64},))
    abs_call(many_const_calls)
    abs_call(many_global_refs, (Int,))
    abs_call(many_invoke_calls, (Vector{Float64},))
    abs_call(many_opaque_closures, (Vector{Float64},))
    # optimization
    @opt_call sin(42)
    @opt_call rand(Float64)
    opt_call(println, (QuoteNode,))
    opt_call(broadcasting, (Vector{Float64},Float64))
    opt_call(completions, (String,Int))
    opt_call(Base.init_stdio, (Ptr{Cvoid},))
    opt_call(many_local_vars, (Int,))
    opt_call(many_method_matches, (Vector{Float64},))
    opt_call(many_const_calls)
    opt_call(many_global_refs, (Int,))
    opt_call(many_invoke_calls, (Vector{Float64},))
    opt_call(many_opaque_closures, (Vector{Float64},))
    # all inference
    @inf_call sin(42)
    @inf_call rand(Float64)
    inf_call(println, (QuoteNode,))
    inf_call(broadcasting, (Vector{Float64},Float64))
    inf_call(completions, (String,Int))
    inf_call(Base.init_stdio, (Ptr{Cvoid},))
    inf_call(many_local_vars, (Int,))
    inf_call(many_method_matches, (Vector{Float64},))
    inf_call(many_const_calls)
    inf_call(many_global_refs, (Int,))
    inf_call(many_invoke_calls, (Vector{Float64},))
    inf_call(many_opaque_closures, (Vector{Float64},))
    return nothing
end

end # module InferenceBenchmarks

using .InferenceBenchmarks

@gctime InferenceBenchmarks.run_all_benchmarks()
