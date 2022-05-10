include("../../utils.jl")

# This benchmark should demonstrate the issue with Time To SafePoint when
# running some threads that allocate and some threads in heavy math code
# that doesn't offer a safepoint.

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
  n = Threads.nthreads() * 2
  Threads.@threads for i in 1:n
      testhelper()
   end
end
        
@gctime test()

