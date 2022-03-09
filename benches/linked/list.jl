using Serialization

mutable struct ListNode
  key::Int64
  next::ListNode
  ListNode() = new()
  ListNode(x)= new(x)
  ListNode(x,y) = new(x,y);
end

function list(n)
    start::ListNode = ListNode(1)
    current::ListNode = start
    for i = 2:n
        current = ListNode(i,current)
    end
end

function bench(iters, tree_size=128)
    times = zeros(Float64, iters)
    for i in 1:iters
        times[i] = @elapsed list(tree_size*1024^2)
    end
    return times
end

serialize(stdout, bench(parse(Int,ARGS[1])))
