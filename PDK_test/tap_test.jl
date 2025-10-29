using Pkg
Pkg.activate(".")  # ensures the environment is used

using DeviceLayout, DeviceLayout.PreferredUnits, FileIO, DeviceLayout.SchematicDrivenLayout
import .SchematicDrivenLayout.ExamplePDK
import .ExamplePDK: add_bridges!, filter_params, tap!, ASSEMBLY_TARGET

tap_style = Paths.CPW(5μm, 25μm)

p = Path(μm)
sty = launch!(p)
straight!(p, 500μm, sty)
tap = tap!(p, tap_style; location=1)
turn!(p, π / 6, 100μm)
straight!(p, 200μm)
turn!(p, -π / 6, 100μm)
straight!(p, 500μm)
straight!(tap, 500μm, sty)
turn!(tap, -π / 6, 100μm)


#terminate!(tap; gap=mr.tap_cap_termination_gap)
g = SchematicGraph("tap_test")
p_node = add_node!(g, p)
tap_node = add_node!(g, tap)

@time "Floorplanning" floorplan = plan(g)
check!(floorplan)

artwork = Cell("tap_test") # "artwork" = "pattern used for fabrication"
@time "Rendering to polygons" render!(artwork, floorplan, ASSEMBLY_TARGET)
#render!(g, identity, strict=:no, simulation=true)
flatten!(artwork)
save(joinpath(@__DIR__, "tap_test.gds"), artwork)
