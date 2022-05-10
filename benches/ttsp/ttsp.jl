include("../../utils.jl")

function work(i,j)
    out = 1
    for x in 1:i
       for y in 1:j
        out = out * x * y
       end
    end
    out
end

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

# Allocate in a loop until anything is pushed into `signal` Channel.
function allocate_in_background()
   list(32)
end
   
function testhelper()
   y = 1024
   if (Threads.threadid() == 1)
      x = 256*1024
      y = work(x,x)
   else
      allocate_in_background()
   end
   y
end

function test() 
  Threads.@threads for i in 1:10
      testhelper()
   end
end
        
@gctime test()

