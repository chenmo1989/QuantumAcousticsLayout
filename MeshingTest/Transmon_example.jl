using Pkg
Pkg.activate(@__DIR__)      # because Project.toml is in SingleTransmon/

# Only instantiate if this env hasn't been instantiated yet
if !isfile(joinpath(Pkg.project().path, "Project.toml"))
	Pkg.instantiate()
end

#using Pkg
#Pkg.activate(".")  # ensures the environment is used
#Pkg.add("Unitful")
#Pkg.add("CSV")
#Pkg.add("DataFrames")
using DeviceLayout, FileIO
import DeviceLayout: μm, nm

include(
	joinpath(@__DIR__, "SingleTransmon.jl"),
)
@time "Total" sm = SingleTransmon.single_transmon(save_gds = true, save_mesh = true)
