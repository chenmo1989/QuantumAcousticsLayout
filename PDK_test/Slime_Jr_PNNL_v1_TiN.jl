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
        total_length=6186μm,
        coupling_length=470μm,
        coupling_gap=5μm,
        bend_radius=50μm,
        n_meander_turns=7,
        total_height=1600μm, # from top hook to bottom hook
        hanger_length=400μm,
        gap_claw=0.8μm,
        α_claw=20°
    )

    rres2 = TaperedClawedMeanderReadout(
        total_length=6079μm,
        coupling_length=250μm,
        coupling_gap=5μm,
        bend_radius=50μm,
        n_meander_turns=7,
        total_height=1600μm, # from top hook to bottom hook
        hanger_length=400μm,
        gap_claw=0.8μm,
        α_claw=20°
    )

    rres3 = TaperedClawedMeanderReadout(
        total_length=5976μm,
        coupling_length=130μm,
        coupling_gap=5μm,
        bend_radius=50μm,
        n_meander_turns=7,
        total_height=1600μm, # from top hook to bottom hook
        hanger_length=400μm,
        gap_claw=0.8μm,
        α_claw=20°
    )
    rres4 = TaperedClawedMeanderReadout(
        total_length=5875μm,
        coupling_length=65μm,
        coupling_gap=5μm,
        bend_radius=50μm,
        n_meander_turns=7,
        total_height=1600μm, # from top hook to bottom hook
        hanger_length=400μm,
        gap_claw=0.8μm,
        α_claw=20°
    )

    rres5 = TaperedClawedMeanderReadout(
        total_length=5779μm,
        coupling_length=20μm,
        coupling_gap=5μm,
        bend_radius=50μm,
        n_meander_turns=7,
        total_height=1600μm, # from top hook to bottom hook
        hanger_length=400μm,
        gap_claw=0.8μm,
        α_claw=20°
    )

    rres6 = TaperedClawedMeanderReadout(
        total_length=5685μm,
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
    rres_node5 = add_node!(g, rres5)
    rres_node6 = add_node!(g, rres6)

    attach!(g, p_feedline_node, rres_node1 => :feedline, 1.25mm, i=4, location=-1)
    attach!(g, p_feedline_node, rres_node2 => :feedline, 1.75mm, i=4, location=1)
    attach!(g, p_feedline_node, rres_node3 => :feedline, 2.25mm, i=4, location=-1)
    attach!(g, p_feedline_node, rres_node4 => :feedline, 2.75mm, i=4, location=1)
    attach!(g, p_feedline_node, rres_node5 => :feedline, 3.25mm, i=4, location=-1)
    attach!(g, p_feedline_node, rres_node6 => :feedline, 3.75mm, i=4, location=1)

    return g
end

function TransmissionLine(g)
    p_feedline = Path(Point(-2350μm, 0μm) - Point(650μm, 0μm); α0=0, metadata=LayerVocabulary.METAL_NEGATIVE) # 650μm is the length of the launcher
    sty = launch!(p_feedline)
    straight!(p_feedline, 4700μm, sty)
    launch!(p_feedline)
    p_feedline_node = add_node!(g, p_feedline)
    return g, p_feedline_node
end

g = assemble_schematic_graph()

@time "Floorplanning" floorplan = plan(g)
# Chip
center_xyz = DeviceLayout.center(floorplan)
chip = centered(Rectangle(7mm, 7mm), on_pt=Point(0mm, 0mm))
# Define rectangle that gets extruded to generate substrate volume
render!(floorplan.coordinate_system, chip, LayerVocabulary.CHIP_AREA)

check!(floorplan)

unit_chip = Cell("unit_chip") # "unit_chip" = "pattern used for fabrication"
@time "Rendering to polygons" render!(unit_chip, floorplan, ASSEMBLY_TARGET)
#render!(g, identity, strict=:no, simulation=true)
flatten!(unit_chip)

# Assemble into a larger 2x2 sample
full_chip = Cell("full_chip")
push!(full_chip.refs, CellArray(unit_chip, Point(0μm, 0μm), dr=Point(0mm, -7mm), dc=Point(7mm, 0mm), nr=2, nc=2))
flatten!(full_chip)

# add chip markups
chip_markings = Cell(uniquename("chip_markup"))
PolyText.polytext!(chip_markings, "CQED Lab @ UW\nSlime Jr v1\nTiN S1", DotMatrix(; pixelsize=18μm, rounding=6μm))
push!(full_chip.refs, CellReference(chip_markings, Point(-3mm, -2.5mm)))

chip_markings = Cell(uniquename("chip_markup"))
PolyText.polytext!(chip_markings, "CQED Lab @ UW\nSlime Jr v1\nTiN S2", DotMatrix(; pixelsize=18μm, rounding=6μm))
push!(full_chip.refs, CellReference(chip_markings, Point(4mm, -2.5mm)))

chip_markings = Cell(uniquename("chip_markup"))
PolyText.polytext!(chip_markings, "CQED Lab @ UW\nSlime Jr v1\nTiN S3", DotMatrix(; pixelsize=18μm, rounding=6μm))
push!(full_chip.refs, CellReference(chip_markings, Point(-3mm, -9.5mm)))

chip_markings = Cell(uniquename("chip_markup"))
PolyText.polytext!(chip_markings, "CQED Lab @ UW\nSlime Jr v1\nTiN S4", DotMatrix(; pixelsize=18μm, rounding=6μm))
push!(full_chip.refs, CellReference(chip_markings, Point(4mm, -9.5mm)))

# add dicing cross
dicing_marker = Cell(uniquename("dicing_marker"))
render!(dicing_marker, centered(Rectangle(1mm, 0.1mm)))
render!(dicing_marker, centered(Rectangle(0.1mm, 1mm)))
push!(full_chip.refs, CellArray(dicing_marker, Point(-3.5mm, 3.5mm), dr=Point(0mm, -7mm), dc=Point(7mm, 0mm), nr=3, nc=3))

flatten!(full_chip)

save(joinpath(@__DIR__, "Slime_Jr_PNNL_v1.gds"), full_chip)