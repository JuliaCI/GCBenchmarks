include(joinpath("..", "..", "..", "util", "utils.jl"))

using Random

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

# tree_size is the number of elements in mb
function tree(n=8)
    n *= 1024^2
    rng = Xoshiro(12345)
    temp = rand(rng, Int, n)
    root::TreeNode = TreeNode(temp[1])
    for i = 2:n
       insert(temp[i], root)
    end
    return sumTree(root)
end

@gctime tree()
