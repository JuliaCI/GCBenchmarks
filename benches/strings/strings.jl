include("../../utils.jl")
using Random

# This program generates random length strings made up of ACTG characters.
# The idea is that there will be a significant number of repeated strings.
# The repeated strings are counted but the strings themselves are garbage.
# The result should be significant multi-sized fragmentation in the heap.

mutable struct TreeNode
   key::String
   count::Int
   left::TreeNode
   right::TreeNode
   next::TreeNode
   TreeNode() = new()
   TreeNode(x) = new(x,1)
   TreeNode(x,y) = new(x,y)
   TreeNode(n::TreeNode) = new(n.key, n.count)
end

function getKey(x::TreeNode) return x.key end
function getCount(x::TreeNode) return x.count end

function compare(g, x::TreeNode, y::TreeNode)
   if (g(x) < g(y))
      return -1
   elseif (g(x) == g(y))
      return 0
   else
      return 1
   end
end
   
function compareCount(x::TreeNode, y::TreeNode)
  return compare(getCount, x, y)
end

function compareKey(x::TreeNode, y::TreeNode)
  return compare(getKey, x, y)
end

function duplicateKey(root::TreeNode, n::TreeNode)
  root.count = root.count + 1;
end

function duplicateCount(root::TreeNode,n::TreeNode)
  if !isdefined(root,:next)
     root.next = n
  else
     n.next = root.next
     root.next = n
  end
end

function insert(root::TreeNode,n::TreeNode,compare,duplicate)
   result = compare(root,n)
   if result < 0
      if !isdefined(root,:left)
         root.left = TreeNode(n)
      else
         insert(root.left, n, compare, duplicate)
      end
   elseif result > 0
      if !isdefined(root,:right)
         root.right = TreeNode(n)
      else
         insert(root.right, n, compare, duplicate)
      end
   else
      duplicate(root,n)
  end
end

function traverse(n::TreeNode, f)
   if isdefined(n,:left)
      traverse(n.left, f)
   end

   f(n)

   if isdefined(n,:right)
      traverse(n.right, f)
   end
end

function print(n::TreeNode)
   count = 1
   while (isdefined(n,:next))
      n = n.next
      count = count + 1
   end
   println("There was/were ", count,  " string(s) that was/were repeated ", n.count, " times")
end

function tree(root::TreeNode, n)
   for i in 1:n
      insert(root, TreeNode(randstring("ACTG", rand(1:32))), compareKey,duplicateKey)
   end
end

resultRoot = TreeNode("end")


function insertHelper(n::TreeNode)
   insert(resultRoot, n, compareCount, duplicateCount)
end

#Build the tree sorted by count
function SortTree(n::TreeNode)
   traverse(n::TreeNode, insertHelper)
   return resultRoot
end

function test(n)
   startroot = TreeNode("start")
   buildtree = tree(startroot, n)   
   result = SortTree(startroot)
#   println("done with sort")
#   traverse(result, print)
   return 6847
end

@gctime test(1024 * 1024 * 32)