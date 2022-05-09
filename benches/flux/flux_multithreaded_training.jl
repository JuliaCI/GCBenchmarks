include("../../utils.jl")
using Flux, Printf, Statistics

# Simple model
function gen_model()
    return Chain(
        Dense(8, 8, σ),
        Dense(8, 8, σ),
        Dense(8, 8, σ),
        Dense(8, 1, σ),
    )
end

# Static dataset
function gen_dataset(batch_size = 128, num_minibatches = 256)
    # Return an array of (x, y) tuples
    return [(
        randn(8, batch_size),
        randn(1, batch_size),
    ) for _ in 1:num_minibatches]
end

# Helper function to print some `@timed` stats
function info_stats(msg, stats, num_epochs)
    @info(
        msg,
        time=stats.time,
        time_per_epoch=stats.time/num_epochs,
        gc=@sprintf("%.1f%%", stats.gctime*100.0/stats.time),
        allocated=Base.format_bytes(stats.bytes),
    )
end


function test()
   # Warm up codegen
#   @info("Warming up Flux.train!()")
   begin
     model = gen_model()
     dataset = gen_dataset()
     opt = Flux.Optimise.ADAM(1e-4)
     num_epochs = 20
     stats = @timed begin
        for idx in 1:num_epochs
            Flux.train!(
                (x, y) -> Flux.Losses.mse(model(x), y),
                Flux.params(model),
                dataset,
                opt,
            )
        end
    end
#    info_stats("First warm-up completed", stats, num_epochs)

    stats = @timed begin
        for idx in 1:4
            Flux.train!(
                (x, y) -> Flux.Losses.mse(model(x), y),
                Flux.params(model),
                dataset,
                opt,
            )
        end
    end
#    info_stats("Second warm-up completed", stats, num_epochs)
   end


   # Train `num_models` in parallel, each on its own thread
   num_models = 32
   datasets = [gen_dataset() for _ in 1:num_models]
   models = [gen_model() for _ in 1:num_models]
   training_stats = [Any[] for _ in 1:num_models]

 #  @warn("Beginning training with $(Threads.nthreads()) threads")
   Threads.@threads for model_idx in 1:num_models
      model = models[model_idx]
      dataset = datasets[model_idx]
      opt = Flux.Optimise.ADAM(1e-4)
    
    # Threads will die off one by one, so we can see how reducing the number of threads
    # eases off GC pressure over the whole cohort
    for idx in 1:(model_idx*num_epochs)
        push!(training_stats[model_idx], @timed begin
            Flux.train!(
                (x, y) -> Flux.Losses.mse(model(x), y),
                Flux.params(model),
                dataset,
                opt,
            )
        end)
    end

    # Calculate mean statistics over the tail end of this thread's lifetime
    tail_stats = training_stats[model_idx][end-num_epochs+1:end]
    mean_stats = (;
        time = mean(s.time for s in tail_stats),
        gctime = mean(s.gctime for s in tail_stats),
        bytes = mean(s.bytes for s in tail_stats),
    )
#    info_stats("Finished model $(model_idx)", mean_stats, model_idx*num_epochs)
    end
end

@gctime test()