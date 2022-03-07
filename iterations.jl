function inner_df(Nrow,Ncol) # Create small dataframe
    rand(Nrow*Ncol)
end

function outer_df(N) #Stack small dataframes
    Nrow=76
    Ncol=21
    df = Vector{Float64}(undef,0)
    for i = 1:N
        append!(df,inner_df(Nrow,Ncol))
    end
    return df
end

function iterated(Niter) # Create a large DataFrame many times.
    for i =1:Niter
        println(i)
        @time pan = outer_df(1000*10*10)
    end
    nothing
end

iterations = parse(Int64, ARGS[1])
iterated(iterations)