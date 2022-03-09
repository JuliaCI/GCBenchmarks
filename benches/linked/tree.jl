using Random
using Serialization

mutable struct TreeNode
   key::Int
   left::TreeNode
   right::TreeNode
   TreeNode() = new()
   TreeNode(x) = new(x)
   TreeNode(x,y,z) = new(x,y,z)
end

function insert(key, n::TreeNode)
   if key < n.key
      if !isdefined(n,:left)
         n.left = TreeNode(key)
      else
         insert(key, n.left)
      end
   elseif key > n.key
      if !isdefined(n,:right)
         n.right = TreeNode(key)
      else
         insert(key, n.right)
      end
   end
end

function sumTree(n::TreeNode)
   sum = n.key
   if isdefined(n,:left)
      sum += sumTree(n.left)
   end
   if isdefined(n,:right)
       sum += sumTree(n.right)
   end

   return sum
end

function tree(n)
    rng = Xoshiro(12345)
    temp = rand(rng, Int, n)
    root::TreeNode = TreeNode(temp[1])
    for i = 2:n
       insert(temp[i], root)
    end
    return sumTree(root)
end

# tree_size is the number of elements in mb
function bench(iters, tree_size=4)
    times = zeros(Float64, iters)
    for i in 1:iters
        times[i] = @elapsed tree(tree_size*1024^2)
    end
    return times
end

serialize(stdout, bench(parse(Int,ARGS[1])))
