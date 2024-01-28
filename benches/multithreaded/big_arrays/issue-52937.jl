include(joinpath("..", "..", "..", "util", "utils.jl"))

using Base.Threads: @threads
using Random: shuffle

function sample_vote!(_rb, chop_counts)
    pts = rand(length(chop_counts))
    N = length(_rb)
    _srt = 4245
    partialsortperm!(_rb, pts, 1:_srt; lt = <, rev = true)
    while sum(@views chop_counts[_rb[1:_srt]]) ≤ 5660
        _srt = min(2 * _srt, N)
        partialsortperm!(_rb, pts, 1:_srt; lt = <, rev = true)
    end
end

function parallel_scores(chop_counts)
    @threads for i in 1:8
        _rb = collect(1:length(chop_counts))
        # the bigger this number, the more % GC time
        for _ ∈ 1:1000
            sample_vote!(_rb, chop_counts)
        end
    end
end

# kind of arbitrary, but approximates my data
chop_counts = shuffle(trunc.(Int, 6500 ./ (50:100_000)))
@gctime parallel_scores(chop_counts)
