include(joinpath("..", "..", "..", "util", "utils.jl"))

# Simple GC benchmark for performance on pointer graphs whose minimum linear arrangement
# has cost θ(n^2). tvbench() maintains a set of N points each of which has a random (x,y)
# coordinate. The points are indexed by two red-black trees, one ordered by x, the other
# one ordered by y. At each step we create a new point and add it to the indexes. If the
# total number of points is N+1 we delete the oldest point.
#
# Author: Todd Veldhuizen
#
# Example use:
# julia> include("tvgcbench.jl")
# julia> tvbench(100000000,1200)
#
# On my macbook pro (64Gb ram, 2.3GHz 8-Core Intel i9) and Julia 1.7.3-pre.3,
# running the above example with some gc tracing enabled I see gc pauses of 24 seconds
# while julia process memory usage is only 5Gb.
#
# Quoted below are some tracing output from julia src/gc.c.
# The fields for the #@GC@# lines are:
# #@GC@# jl_gc_pass_count, jl_mark_counter, jl_marked_already_counter, pause, t0, d1, mark_time, d3, d4, d5, sweep_time, d7, sweep_full
#
# #@GC@# 4,59679,312306,9493554,6673304950506491,21985,5996094,1442,474,1186,3466187,6630,0
# #@GC_PAUSE_SECONDS@# 0.009494
# #@GC@# 5,1262302,1707391,155991578,6673305957633691,26669,146731925,2207,404,1357,9224256,5281,0
# #@GC_PAUSE_SECONDS@# 0.155992
# #@GC@# 6,2601172,3271231,309064862,6673307232597647,14024,294877138,1636,2092,498,14167736,2297,0
# #@GC_PAUSE_SECONDS@# 0.309065
# #@GC@# 7,3963665,4837077,484216108,6673308816193910,5398,456634339,1967,137,26211,27546197,2528,1
# #@GC_PAUSE_SECONDS@# 0.484216
# #@GC@# 8,8451979,11612046,948559090,6673312801368228,2831,912492807,4107,836,82544,35974458,2023,1
# #@GC_PAUSE_SECONDS@# 0.948559
# #@GC@# 9,16979033,21842180,1954845268,6673323797397558,7148,1892234116,3718,750,19069,62580629,2001,1
# #@GC_PAUSE_SECONDS@# 1.954845
# #@GC@# 10,38296771,47417640,4937244893,6673355028202042,3998,4802409026,4815,886,83290,134740941,2644,1
# #@GC_PAUSE_SECONDS@# 4.937245
# #@GC@# 11,91590987,111356129,13998846831,6673446463639536,4052,13686747979,3716,1155,49822,312038121,2555,1
# #@GC_PAUSE_SECONDS@# 13.998847
# #@GC@# 12,144885203,175294623,24036204691,6673554514445920,3224,23551304164,4770,949,57853,484831470,2825,1
# #@GC_PAUSE_SECONDS@# 24.036205
#
# In GC pass 12 (which lasts 24 seconds) there are (144885203+175294623) calls to
# gc_try_setmark() and the mark phase takes 23551304164ns, so about 73ns (approx 170
# clock cycles) per mark attempt. My suspicion is that the poor gc performance on this
# benchmark is caused by the mark phase doing inefficient random memory accesses with
# no prefetching, causing cache and TLB misses. On the STREAMS benchmark my laptop does
# about 18GB/s, so in the length of that 24 second gc pause it could linearly scan the
# entire julia process memory 85 times.

using DataStructures
using Random
import Base: isless

mutable struct Point
    x::Int
    y::Int
end

struct PointByX
    p::Point
end
Base.isless(a::PointByX, b::PointByX) = isless(a.p.x, b.p.x)

struct PointByY
    p::Point
end
Base.isless(a::PointByY, b::PointByY) = isless(a.p.y, b.p.y)

function tvbench(; N = 50_000_000)
    t0 = time()
    queue = Queue{Point}()
    xtree = RBTree{PointByX}()
    ytree = RBTree{PointByY}()
    count = 0
    tcheck = 0
    i = 0
    while true
        count = count + 1
        p = Point(Random.rand(Int), Random.rand(Int))
        enqueue!(queue, p)
        push!(xtree, PointByX(p))
        push!(ytree, PointByY(p))

        if length(queue) > N
            p = dequeue!(queue)
            delete!(xtree, PointByX(p))
            delete!(ytree, PointByY(p))
        end

        i = i + 1
        if i == 100
            i = 0
            @assert length(xtree) <= N
            elapsed = time() - t0
            tcheck2 = floor(elapsed/10)
            if tcheck != tcheck2
                tcheck = tcheck2
                println("elapsed=$(elapsed)s, $(length(queue)) current points, $(count) total, $(floor(count/elapsed)) per second")
            end
            if count >= 2 * N
                break
            end
	end
        #=
        nm, nr = fldmod(count, 1_000_000)
        if nr == 0
            @show nm
            @timev GC.gc()
        end
        elapsed = time() - t0
        if (elapsed >= min_seconds) && ((count >= N) || (elapsed >= max_seconds))
            break
        end
        =#
    end
end

@gctime tvbench()
