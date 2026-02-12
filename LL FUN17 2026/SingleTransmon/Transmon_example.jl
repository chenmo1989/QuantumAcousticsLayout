using Pkg
Pkg.activate(@__DIR__)      # because Project.toml is in SingleTransmon/

# Only instantiate if this env hasn't been instantiated yet
if !isfile(joinpath(Pkg.project().path, "Project.toml"))
    Pkg.instantiate()
end

include(joinpath(@__DIR__, "SingleTransmon_fullchip.jl"))

@time "Total" sm = SingleTransmon.single_transmon(save_gds=true)
