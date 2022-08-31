const doc = """lower_bound_overhead.jl -- Cost metric taken from `Distilling the Real Cost of
Production Garbage Collectors` by Cai et al.
Usage:
    lower_bound_overhead.jl <json>...
Options:
    -h, --help                            Show this screen.
"""

using DocOpt
using JSON
using PrettyTables

const args = docopt(doc, version = v"0.1.1")

function main(args)
    files = args["<json>"]

    # minimum distilled costs
    local mdcs = Dict{String, Float64}()
    #lower bound overheads
    local lbos = Dict{String, Float64}()

    for file in files
        js = JSON.parsefile(file)
        # using medians
        total_time = js["total time"][2]
        gc_time = js["gc time"][2]
        mdcs[file] = total_time - gc_time
    end

    mdc = reduce(min, values(mdcs))

    for file in files
        js = JSON.parsefile(file)
        # using medians
        total_time = js["total time"][2]
        lbos[file] = total_time - mdc
    end

    labels = ["lower bound overhead [ms]"]
    header = [""; files]
    raw_data = [lbos[file] for file in files]
    data = hcat(labels, raw_data')
    pretty_table(data, header, formatters=ft_printf("%0.0f"))
end

main(args)
