include(joinpath("..", "..", "..", "utils.jl"))

using TimeZones

zdts = [now(tz"UTC") for _ in  1:100_000_000];

@gctime sum(hash, ["trashfire"^min(1000, i) for i in 1:100_000])

