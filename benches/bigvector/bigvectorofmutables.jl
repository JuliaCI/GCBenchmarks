

include("../../utils.jl")

# alloc(_) = Core.donotdelete(map(_->Ref(0), (1<<30)÷sizeof(Int)))
alloc(_) = Core.donotdelete(fill(Ref(0), (1<<30)÷sizeof(Int)))

@gctime foreach(alloc, 1:10)


