include("../../utils.jl")
using TimeZones

zdts = [now(tz"UTC") for _ in  1:100_000_000];

n::Int = parse(Int,ARGS[1])
@gctime n sum(hash, ["trashfire"^min(1000, i) for i in 1:100_000])

