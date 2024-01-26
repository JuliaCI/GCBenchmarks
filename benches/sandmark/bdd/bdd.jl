include(joinpath("..", "..", "..", "utils.jl"))

# Translated from OCaml to Julia
# Original code at https://github.com/ocaml-bench/sandmark/blob/main/benchmarks/bdd/bdd.ml

abstract type BDD end

struct One <: BDD end
struct Zero <: BDD end
struct Node <: BDD
    l::BDD
    v::Int
    id::Int
    h::BDD
end

function compute(bdd::BDD, vars::Vector{Bool})
    if bdd isa Zero
        return false
    elseif bdd isa One
        return true
    elseif bdd isa Node
        if vars[bdd.v]
            return compute(bdd.h, vars)
        else
            return compute(bdd.l, vars)
        end
    end
end

function get_id(bdd::BDD)
    if bdd isa Node
        return bdd.id
    elseif bdd isa Zero
        return 0
    elseif bdd isa One
        return 1
    end
end

const init_size_1 = 8 * 1024 - 1
const node_c = Ref(1)
const sz_1 = Ref(init_size_1)
const htab = Ref(fill(Vector{BDD}(), init_size_1 + 1))
const n_items = Ref(0)

function hash_val(x, y, v)
    return x << 1 + y + v << 2
end

function resize(new_size)
    arr = htab[]
    new_sz_1 = new_size - 1
    new_arr = fill(Vector{BDD}(), new_size)

    function copy_bucket(bucket)
        for n in bucket
            if n isa Node
                ind = hash_val(get_id(n.l), get_id(n.h), n.v) & new_sz_1 + 1
                push!(new_arr[ind], n)
            else
                error("Unexpected node type in bucket")
            end
        end
    end

    for n = 1:sz_1[]
        copy_bucket(arr[n])
    end

    htab[] = new_arr
    sz_1[] = new_sz_1
end

function insert!(idl, idh, v, ind, bucket, newNode)
    if n_items[] <= sz_1[]
        htab[][ ind ] = [newNode, bucket...]
        n_items[] += 1
    else
        resize(sz_1[] + sz_1[] + 2)
        ind = hash_val(idl, idh, v) & sz_1[] + 1
        htab[][ ind ] = [newNode, htab[][ ind ]...]
    end
end

function reset_unique()
    sz_1[] = init_size_1
    htab[] = fill(Vector{BDD}, sz_1[] + 1)
    n_items[] = 0
    node_c[] = 1
end

function mk_node(low, v, high)
    idl = get_id(low)
    idh = get_id(high)

    if idl == idh
        return low
    else
        ind = hash_val(idl, idh, v) & sz_1[] + 1
        bucket = htab[][ ind ]
        function lookup(b)
            if isempty(b)
                new_node = Node(low, v, node_c[], high)
                insert!(idl, idh, v, ind, bucket, new_node)
                return new_node
            else
                n = b[1]
                if n isa Node
                    if v == n.v && idl == get_id(n.l) && idh == get_id(n.h)
                        return n
                    else
                        return lookup(b[2:end])
                    end
                else
                    error("Unexpected node type in bucket")
                end
            end
        end
        return lookup(bucket)
    end
end

const LESS = :LESS
const EQUAL = :EQUAL
const GREATER = :GREATER

function cmp_var(x, y)
    if x < y
        return LESS
    elseif x > y
        return GREATER
    else
        return EQUAL
    end
end

const zero = Zero()
const one = One()

function mk_var(x)
    return mk_node(zero, x, one)
end

const cache_size = 1999
andslot1 = fill(0, cache_size)
andslot2 = fill(0, cache_size)
andslot3 = Vector{BDD}(undef, cache_size)
fill!(andslot3, zero)
xorslot1 = fill(0, cache_size)
xorslot2 = fill(0, cache_size)
xorslot3 = Vector{BDD}(undef, cache_size)
fill!(xorslot3, zero)
notslot1 = fill(0, cache_size)
notslot2 = Vector{BDD}(undef, cache_size)
fill!(notslot2, zero)

function hash(x, y)
    return (x << 1 + y) % cache_size + 1
end

function not_node(n)
    if n isa Zero
        return one
    elseif n isa One
        return zero
    elseif n isa Node
        h = n.id % cache_size
        if n.id == notslot1[h]
            return notslot2[h]
        else
            f = mk_node(not_node(n.l), n.v, not_node(n.h))
            notslot1[h] = n.id
            notslot2[h] = f
            return f
        end
    end
end

function and2(n1, n2)
    if n1 isa Node
        if n2 isa Node
            h = hash(n1.id, n2.id)
            if n1.id == andslot1[h] && n2.id == andslot2[h]
                return andslot3[h]
            else
                f = if cmp_var(n1.v, n2.v) == EQUAL
                    mk_node(and2(n1.l, n2.l), n1.v, and2(n1.h, n2.h))
                elseif cmp_var(n1.v, n2.v) == LESS
                    mk_node(and2(n1.l, n2), n1.v, and2(n1.h, n2))
                else
                    mk_node(and2(n1, n2.l), n2.v, and2(n1, n2.h))
                end
                andslot1[h] = n1.id
                andslot2[h] = n2.id
                andslot3[h] = f
                return f
            end
        elseif n2 isa Zero
            return zero
        elseif n2 isa One
            return n1
        end
    elseif n1 isa Zero
        return zero
    elseif n1 isa One
        return n2
    end
end

function xor(n1, n2)
    if n1 isa Node
        if n2 isa Node
            h = hash(n1.id, n2.id)
            if n1.id == xorslot1[h] && n2.id == xorslot2[h]
                return xorslot3[h]
            else
                f = if cmp_var(n1.v, n2.v) == EQUAL
                    mk_node(xor(n1.l, n2.l), n1.v, xor(n1.h, n2.h))
                elseif cmp_var(n1.v, n2.v) == LESS
                    mk_node(xor(n1.l, n2), n1.v, xor(n1.h, n2))
                else
                    mk_node(xor(n1, n2.l), n2.v, xor(n1, n2.h))
                end
                xorslot1[h] = n1.id
                xorslot2[h] = n2.id
                xorslot3[h] = f
                return f
            end
        elseif n2 isa Zero
            return n1
        elseif n2 isa One
            return not_node(n1)
        end
    elseif n1 isa Zero
        return n2
    elseif n1 isa One
        return not_node(n2)
    end
end

function hwb(n)
    function h(i, j)
        if i == j
            return mk_var(i)
        else
            return xor(and2(not_node(mk_var(j)), h(i, j - 1)),
                       and2(mk_var(j), g(i, j - 1)))
        end
    end

    function g(i, j)
        if i == j
            return mk_var(i)
        else
            return xor(and2(not_node(mk_var(i)), h(i + 1, j)),
                       and2(mk_var(i), g(i + 1, j)))
        end
    end

    return h(0, n - 1)
end

# Testing
seed = 0

function random()
    global seed
    seed = seed * 25173 + 17431
    return (seed & 1) > 0
end

function random_vars(n)
    return [random() for _ in 1:n]
end

function test_hwb(bdd, vars)
    ntrue = sum(vars)
    return compute(bdd, vars) == (ntrue > 0 ? vars[ntrue] : false)
end

function main()
    n = 26
    ntests = 100
    bdd = hwb(n)
    succeeded = true
    for _ in 1:ntests
        succeeded &= test_hwb(bdd, random_vars(n))
    end
    # TODO: @assert succeeded
end

@gctime main()
