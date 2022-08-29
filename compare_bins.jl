const doc = """compare_bin.jl -- Cross binary comparison between GC benchmarks
Usage:
    compare_bins.jl <json1> <json2>
Options:
    -h, --help                            Show this screen.
"""

using DocOpt
using JSON
using PrettyTables

const args = docopt(doc, version = v"0.1.1")

function main(args)
    f1 = args["<json1>"]
    f2 = args["<json2>"]

    js1 = JSON.parsefile(f1)
    js2 = JSON.parsefile(f2)

    labels = ["total time ",
              "gc time ",
              "mark time",
              "sweep time",
              "max pause",
              "max memory",
              "pct gc"]
    header = ["", f1, f2]

    # show medians
    raw_data = [js1["total time"][2] js2["total time"][2];
                js1["gc time"][2] js2["gc time"][2];
                js1["mark time"][2] js2["mark time"][2];
                js1["sweep time"][2] js2["sweep time"][2];
                js1["max pause"][2] js2["max pause"][2];
                js1["max memory"][2] js2["max memory"][2];
                js1["pct gc"][2] js2["pct gc"][2]]

    data = hcat(labels, raw_data)
    pretty_table(data, header, formatters=ft_printf("%0.0f"))
end

main(args)
