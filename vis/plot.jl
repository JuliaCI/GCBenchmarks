using CSV
using CairoMakie
using TypedTables
using Statistics

struct IntegerTicks end
CairoMakie.Makie.get_tickvalues(::IntegerTicks, vmin, vmax) = ceil(Int, vmin) : floor(Int, vmax)

function plot_results(table; log2_axes = true, violin = true)
	kwargs = (;)
	if log2_axes
		kwargs = (; xscale = log2, yscale = log2, xticks = LogTicks(IntegerTicks()), kwargs...)
	end 

	benches = TypedTables.group(getproperty(:file), table)
	f = Figure(resolution = (1000, 500*length(benches)))
	idx = 1
	for (file, bench) in pairs(benches)
		mean_data = Any[]
		for (gcthreads, t) in pairs(TypedTables.group(getproperty(:gcthreads), bench))
			push!(mean_data, (; file, gcthreads, mark_time = mean(t.mark_time), threads=first(t.threads)))
		end
		mean_table = Table(row for row in mean_data)
		t0 = filter(r -> r.gcthreads == 0, mean_table).mark_time
		speedup = t0 ./ mean_table.mark_time
		mean_table = Table(mean_table; speedup)

		Label(f[idx, 1:2, Top()], 
			"$file -- $(first(mean_table.threads)) Threads", 
			valign = :bottom,font = :bold, padding = (0, 0, 15, 0))
		
		ax = Axis(f[idx, 1]; title="Speedup", kwargs...)
		scatterlines!(ax, mean_table.gcthreads .+ 1, mean_table.speedup)
		lines!(ax, mean_table.gcthreads .+ 1, mean_table.gcthreads .+ 1, color=:lightblue)

		ax = Axis(f[idx, 2]; title="Mark times (ms)", kwargs...)
		gcthreads = bench.gcthreads .+ 1
		mark_times = bench.mark_time ./ 1_000_000
		if violin
			violin!(ax, gcthreads, mark_times;
				show_median=true)
		else
			rainclouds!(ax,gcthreads, mark_times;
				orientation = :vertical, clouds=hist, cloud_width=0.5)
		end
	
		idx +=1
	end
	save("plot.png", f, px_per_unit = 2)
	f
end


if !isinteractive()
	table = Table(CSV.File(joinpath(@__DIR__, "..", "results.csv")))
	plot_results(table)
end
