using Pkg
Pkg.activate(@__DIR__)      # because Project.toml is in SingleTransmon/
Pkg.instantiate()           # safe; after first time it’s fast

include(joinpath(@__DIR__, "SingleTransmon.jl"))

@time "Total" sm = SingleTransmon.single_transmon(save_gds=true)
