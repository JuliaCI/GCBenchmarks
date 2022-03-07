using Random
using Printf

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

@time list(128*1024*1024)