using Pkg
Pkg.activate(".")  # ensures the environment is used

using DeviceLayout, DeviceLayout.PreferredUnits, FileIO, DeviceLayout.SchematicDrivenLayout
import .SchematicDrivenLayout.ExamplePDK
import .ExamplePDK: add_bridges!, filter_params, tap!, ASSEMBLY_TARGET
using .ExamplePDK.LayerVocabulary

p = Path(metadata=METAL_NEGATIVE)
sty = launch!(p)
straight!(p, 500μm, sty)

taper_trace = 1μm
taper_gap = 0.5μm
taper_length = 5μm
r_taper = 10μm

gap_claw = 1μm

w_claw = 100μm # width
r_claw = 20μm # radius
l_claw = 50μm # length
α_claw = 20°

taper_style = Paths.CPW(taper_trace, taper_gap)

# start the tap
main_sty = laststyle(p)
main_sty isa Paths.CPW || error("Last path style should be CPW for a CPW tap")
main_trace = Paths.trace(main_sty, pathlength(p[end]))
main_gap = Paths.gap(main_sty, pathlength(p[end]))
location = 1

tap1 = Path(
    p1(p) + main_trace / 2 * Point(cos(α1(p)), sin(α1(p)))
    -
    sign(location) * main_trace / 2 * Point(-sin(α1(p)), cos(α1(p))), # shift sideways by main_trace/2, so tap1 starts from the gap of the main trace
    α0=α1(p) - sign(location) * 90°,
    metadata=p.metadata,
    name=uniquename("tap")
)

tap2 = Path(
    p1(p) + main_trace / 2 * Point(cos(α1(p)), sin(α1(p)))
    +
    sign(location) * main_trace / 2 * Point(-sin(α1(p)), cos(α1(p))), # shift sideways by main_trace/2, so tap1 starts from the gap of the main trace
    α0=α1(p) + sign(location) * 90°,
    metadata=p.metadata,
    name=uniquename("tap")
)

# terminate the main path
norender = Paths.SimpleNoRender(main_trace, virtual=true)
straight!(p, main_trace, norender)
straight!(p, 0μm, Paths.CPW(main_trace, 0μm))
terminate!(p; gap=main_gap)

# tap1
straight!(tap1, taper_trace / 2 + taper_gap, main_sty)
turn!(tap1, 90° + α_claw, r_claw)
l_taper = (r_claw * cos(α_claw) + main_trace / 2 - r_taper * (1 - cos(α_claw))) / sin(α_claw)
straight!(tap1, l_taper, Paths.Taper())
turn!(tap1, -α_claw, r_taper, taper_style) #2 * (w_claw + r_claw + main_trace / 2 - gap_claw / 2), Paths.Taper())
straight!(tap1, taper_length)
terminate!(tap1; gap=taper_gap)

# tap2
straight!(tap2, taper_trace / 2 + taper_gap, main_sty)
turn!(tap2, -90° - α_claw, r_claw)
straight!(tap2, l_taper, Paths.Taper())
turn!(tap2, α_claw, r_taper, taper_style) #2 * (w_claw + r_claw + main_trace / 2 - gap_claw / 2), Paths.Taper())
straight!(tap2, taper_length)
terminate!(tap2; gap=taper_gap)

# now, fill in the center!
pt0 = p1(p)
narc = 197
h = 0μm

seg = segment(tap1[2])
pts = map(seg, range(pathlength(seg), stop=zero(h), length=narc))
push!(pts, Paths.p1(segment(tap1[3])))
seg = segment(tap1[4])
pts2 = map(seg, range(pathlength(seg), stop=zero(h), length=narc))
append!(pts, pts2)

h != zero(h) && push!(pts, Paths.p0(p))
poly = Polygon(pts) + Point(zero(h), h) # + Point(0.0, (r-h)/2)
cc = Cell("claw", nm)
render!(cc, poly, METAL_POSITIVE)

attach!(p, CellReference(cc, Point(0μm, 0μm)), (40μm):(40μm):((pathlength(p[end]))-40μm))
g = SchematicGraph("tap_test")
p_node = add_node!(g, p)
tap1_node = add_node!(g, tap1)
tap2_node = add_node!(g, tap2)

@time "Floorplanning" floorplan = plan(g)
check!(floorplan)

artwork = Cell("tap_test") # "artwork" = "pattern used for fabrication"
@time "Rendering to polygons" render!(artwork, floorplan, ASSEMBLY_TARGET)
#render!(g, identity, strict=:no, simulation=true)
flatten!(artwork)
save(joinpath(@__DIR__, "tap_test2.gds"), artwork)
