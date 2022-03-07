using Random
using Printf

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

function printTree(n::TreeNode)
   if isdefined(n,:left)
      printTree(n.left)
   end

   @printf("node = %d\n", n.key)

   if isdefined(n,:right)
      printTree(n.right)
   end
end

function sumTree(n::TreeNode)
   sum = 0
   if isdefined(n,:left)
      sum += sumTree(n.left)
   end

   sum += n.key

   if isdefined(n,:right)
       sum += sumTree(n.right)
   end

   return sum
end


function tree(n)
    rng = MersenneTwister(12345)
    temp = rand(rng, Int, n)
    root::TreeNode = TreeNode(temp[1])
    for i = 2:n
       insert(temp[i], root)
    end
    @printf("\n\nSum of %d numbers = %d\n\n ", n, sumTree(root))
end

function test(iters, n)
   for i = 1:iters
    @time tree(n)
   end
end

# iterations is the number of trees
# tree_size is the number of elements in mb
rng = MersenneTwister(12345)
iterations = parse(Int64, ARGS[1])
tree_size = parse(Int64, ARGS[2])


test(iterations, tree_size * 1024 * 1024)