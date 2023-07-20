include(joinpath("..", "..", "..", "utils.jl"))

const N = 2500
a = Vector{Vector{Float64}}(undef,N)

function alloc_alot()
     for j in 1:1000
       Threads.@threads for i in 1:N
           a[i] = rand(2500)
       end
     end
       end

@gctime alloc_alot()
