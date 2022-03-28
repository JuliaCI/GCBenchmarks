using Printf
import Unicode: ispunct

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
   println("TreeNode ", n.count , ":", n.key)
   while (isdefined(n,:next))
      n = n.next
      println("     ", n.key)
   end
   println(" ")
end

#Build the tree sorted by words
function tree(root::TreeNode, file::String)
   f = open(file) do foo
      for l in eachline(foo)
         bar = split(l, " ")
         for s in bar
            s = lowercase(s)
            s = filter(!ispunct,s)
            for i in 1:1000
               insert(root, TreeNode("scoobydoobydoo"), compareKey, duplicateKey)
            end
            insert(root, TreeNode(s), compareKey, duplicateKey)
            for i in 1:1000 
               insert(root, TreeNode("shaggy"), compareKey, duplicateKey)
            end
         end
      end
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

function test(dirName::String)
   startroot = TreeNode("start")
   dir = joinpath(@__DIR__, "txtfiles")
   cd(dir)
   for file in readdir()
      println("opening file: ", file)
      tree(startroot, file)
   end
   println("done with files")
#   traverse(startroot,print)
   result = SortTree(startroot)
   println("done with sort")
#   traverse(result, print)
end

@time(test("txtfiles"))