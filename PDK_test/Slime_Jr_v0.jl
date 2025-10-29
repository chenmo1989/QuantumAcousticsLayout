using Pkg
Pkg.activate(".")  # ensures the environment is used
using FileIO, CSV, DataFrames, JSON, JSONSchema
using DeviceLayout, DeviceLayout.PreferredUnits, DeviceLayout.SchematicDrivenLayout
import DeviceLayout: μm, nm
import .SchematicDrivenLayout.ExamplePDK
import .SchematicDrivenLayout.ExamplePDK: LayerVocabulary, L1_TARGET, ASSEMBLY_TARGET, add_bridges!
using .ExamplePDK.Transmons, .ExamplePDK.ReadoutResonators, .ExamplePDK.ChipTemplates
import .ExamplePDK.SimpleJunctions: ExampleSimpleJunction
import DeviceLayout: uconvert
using PRIMA
include("tapered_claw_test_using_path.jl")

# This script assembles a simple chip with one resonator. We mainly use this to test out the resonator module (in this case, "tapered_claw_test_using_path.jl"), and use this to export to COMSOL for simulation.

function assemble_schematic_graph()
    g = SchematicGraph("simplechip")
    # Feedline
    g, p_feedline_node = TransmissionLine(g)
    ## Resonator
    rres1 = TaperedClawedMeanderReadout(
        total_length=5670μm,
        coupling_length=500μm,
        coupling_gap=5μm,
        bend_radius=50μm,
        n_meander_turns=7,
        total_height=1600μm, # from top hook to bottom hook
        hanger_length=400μm,
        gap_claw=0.8μm,
        α_claw=20°
    )
    rres2 = TaperedClawedMeanderReadout(
        total_length=5581μm,
        coupling_length=150μm,
        coupling_gap=5μm,
        bend_radius=50μm,
        n_meander_turns=7,
        total_height=1600μm, # from top hook to bottom hook
        hanger_length=400μm,
        gap_claw=0.8μm,
        α_claw=20°
    )
    rres3 = TaperedClawedMeanderReadout(
        total_length=5492μm,
        coupling_length=30μm,
        coupling_gap=5μm,
        bend_radius=50μm,
        n_meander_turns=7,
        total_height=1600μm, # from top hook to bottom hook
        hanger_length=400μm,
        gap_claw=0.8μm,
        α_claw=20°
    )
    rres4 = TaperedClawedMeanderReadout(
        total_length=5403μm,
        coupling_length=5μm,
        coupling_gap=5μm,
        bend_radius=50μm,
        n_meander_turns=7,
        total_height=1600μm, # from top hook to bottom hook
        hanger_length=400μm,
        gap_claw=0.8μm,
        α_claw=20°
    )
    rres_node1 = add_node!(g, rres1)
    rres_node2 = add_node!(g, rres2)
    rres_node3 = add_node!(g, rres3)
    rres_node4 = add_node!(g, rres4)

    attach!(g, p_feedline_node, rres_node1 => :feedline, 1mm, i=4, location=-1)
    attach!(g, p_feedline_node, rres_node2 => :feedline, 1mm, i=4, location=1)
    attach!(g, p_feedline_node, rres_node3 => :feedline, 2mm, i=4, location=1)
    attach!(g, p_feedline_node, rres_node4 => :feedline, 2mm, i=4, location=-1)

    return g
end

function TransmissionLine(g)
    p_feedline = Path(Point(-1350μm, 0μm) - Point(650μm, 0μm); α0=0, metadata=LayerVocabulary.METAL_NEGATIVE) # 650μm is the length of the launcher
    sty = launch!(p_feedline)
    straight!(p_feedline, 2700μm, sty)
    launch!(p_feedline)
    p_feedline_node = add_node!(g, p_feedline)
    return g, p_feedline_node
end

g = assemble_schematic_graph()

@time "Floorplanning" floorplan = plan(g)
# Chip
center_xyz = DeviceLayout.center(floorplan)
chip = centered(Rectangle(5mm, 5mm), on_pt=Point(0mm, 0mm))
# Define rectangle that gets extruded to generate substrate volume
render!(floorplan.coordinate_system, chip, LayerVocabulary.CHIP_AREA)

check!(floorplan)

artwork = Cell("simplechip") # "artwork" = "pattern used for fabrication"
@time "Rendering to polygons" render!(artwork, floorplan, ASSEMBLY_TARGET)
#render!(g, identity, strict=:no, simulation=true)

# add chip markups
chip_markings = Cell("chip_markup")
PolyText.polytext!(chip_markings, "CQED Lab @ UW\nSlime Jr v0", DotMatrix(; pixelsize=15μm, rounding=6μm))
push!(artwork.refs, CellReference(chip_markings, Point(-2mm, -1.8mm)))

flatten!(artwork)

save(joinpath(@__DIR__, "Slime_Jr_v0.gds"), artwork)