include(joinpath("..", "..", "..", "utils.jl"))

#  This is adapted from a benchmark written by John Ellis and Pete Kovac
#  of Post Communications.
#  It was modified by Hans Boehm of Silicon Graphics.
# 
#  	This is no substitute for real applications.  No actual application
# 	is likely to behave in exactly this way.  However, this benchmark was
# 	designed to be more representative of real applications than other
# 	Java GC benchmarks of which we are aware.
# 	It attempts to model those properties of allocation requests that
# 	are important to current GC techniques.
# 	It is designed to be used either to obtain a single overall performance
# 	number, or to give a more detailed estimate of how collector
# 	performance varies with object lifetimes.  It prints the time
# 	required to allocate and collect balanced binary trees of various
# 	sizes.  Smaller trees result in shorter object lifetimes.  Each cycle
# 	allocates roughly the same amount of memory.
# 	Two data structures are kept around during the entire process, so
# 	that the measured performance is representative of applications
# 	that maintain some live in-memory data.  One of these is a tree
# 	containing many pointers.  The other is a large array containing
# 	double precision floating point numbers.  Both should be of comparable
# 	size.
# 
# 	The results are only really meaningful together with a specification
# 	of how much memory was used.  It is possible to trade memory for
# 	better time performance.  This benchmark should be run in a 32 MB
# 	heap, though we don't currently know how to enforce that uniformly.
# 
# 	Unlike the original Ellis and Kovac benchmark, we do not attempt
#  	measure pause times.  This facility should eventually be added back
# 	in.  There are several reasons for omitting it for now.  The original
# 	implementation depended on assumptions about the thread scheduler
# 	that don't hold uniformly.  The results really measure both the
# 	scheduler and GC.  Pause time measurements tend to not fit well with
# 	current benchmark suites.  As far as we know, none of the current
# 	commercial Java implementations seriously attempt to minimize GC pause
# 	times.
# 
# 	Known deficiencies:
# 		- No way to check on memory use
# 		- No cyclic data structures
# 		- No attempt to measure variation with object size
# 		- Results are sensitive to locking cost, but we dont
# 		  check for proper locking

mutable struct Node 
   left::Node
   right::Node
   i::Int
   j::Int
   Node() = new()
   Node(x,y) = new(x,y)
end

kStretchTreeDepth = 18
kStretchTreeDepth = 18	   #  about 16Mb
kLongLivedTreeDepth = 16   #  about 4Mb
kArraySize = 500000        #  about 4Mb
kMinTreeDepth = 4
kMaxTreeDepth = 16

#  Nodes used by a tree of a given size
TreeSize(i::Int)::Int = ((1 << (i + 1)) - 1)

#  Number of iterations to use for a given tree depth
NumIters(i::Int)::Int = floor(2 * TreeSize(kStretchTreeDepth) / TreeSize(i));

function Populate(iDepth::Int, thisNode::Node) 
	 if (iDepth<=0) 
		return
         else 
		iDepth = iDepth - 1;
		thisNode.left  = Node();
		thisNode.right = Node();
		Populate(iDepth, thisNode.left);
		Populate(iDepth, thisNode.right);
	end
end

#  Build tree bottom-up
function MakeTree(iDepth::Int) 
   if (iDepth<=0) return Node()
	else return Node(MakeTree(iDepth-1),
		            MakeTree(iDepth-1))
   end                            
end

function PrintDiagnostics() 
   print(" Diagnostics:  Total memory available=", Sys.total_memory(), " bytes")
   print("  Free memory=", Sys.free_memory(), " bytes", "\n");
end

function TimeConstruction(depth::Int) 
         iNumIters::Int = NumIters(depth)
	 print("Creating ", iNumIters," trees of depth ", depth, "\n")
         tStart = time_ns()
         for i = 0:iNumIters
            tempTree = Node()
	    Populate(depth, tempTree)
	    tempTree = Node()
         end
	 tFinish = time_ns()
         print("\tTop down construction took ",
				  (tFinish - tStart)/1_000_000, "msecs\n")
         tStart = time_ns()
         for i = 0:iNumIters
            tempTree = MakeTree(depth)
            tempTree = Node()
          end
	 tFinish = time_ns()
         print("\tBottom up construction took ",
                                   (tFinish - tStart)/1_000_000, "msecs\n");
		
end

function run() 
   print("Garbage Collector Test\n")
   print(" Stretching memory with a binary tree of depth ",
			kStretchTreeDepth, "\n")
   PrintDiagnostics()
   tStart = time_ns()
   #  Stretch the memory space quickly
   tempTree = MakeTree(kStretchTreeDepth)
   tempTree = Node()

   #  Create a long lived object
   print(" Creating a long-lived binary tree of depth ",
        kLongLivedTreeDepth,"\n")

   longLivedTree = Node();
   Populate(kLongLivedTreeDepth, longLivedTree);

   #  Create long-lived array, filling half of it
   print(" Creating a long-lived array of ",
		 kArraySize , " doubles\n")

   array = Array{Float64}(undef, kArraySize)
   for i=1:250000
      array[i] = 1.0/i;
   end
   PrintDiagnostics();

   for d in [4,6,8,10,12,14,16]
      TimeConstruction(d);
   end   

   # Figure out how to enure LongLivedTree is still alive
   if (array[1000] != 1.0/1000)
      print("Failed")
   end

   #  fake reference to LongLivedTree
   #  and array
   #  to keep them from being optimized away

   tFinish = time_ns()
   tElapsed = tFinish-tStart;
   PrintDiagnostics();
   print("Completed in ", tElapsed/1_000_000, "ms.\n")
end

@gctime run()

