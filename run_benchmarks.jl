using Statistics
using Serialization

dir = joinpath(@__DIR__, "benches")
cd(dir)
for category in readdir()
    @show category
    cd(category)
    for test in readdir()
        @show test
        times = open(deserialize, `julia --project=. $test 10`)
        println("median time: ", median(times))
    end
    cd("..")
end

