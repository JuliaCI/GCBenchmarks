include("../../utils.jl")

mutable struct ListNode
  key::Int64
  next::ListNode
  ListNode() = new()
  ListNode(x)= new(x)
  ListNode(x,y) = new(x,y);
end

function list(n=128)
    start::ListNode = ListNode(1)
    current::ListNode = start
    for i = 2:(n*1024^2)
        current = ListNode(i,current)
    end
    return current.key
end

n::Int = parse(Int,ARGS[1])
@gctime n list()

