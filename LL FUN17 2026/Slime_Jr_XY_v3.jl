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
    g, p_xye_node1,p_xye_node2,p_xye_node3,p_xye_node4 = xy_electrode_line(g)
    ## Resonator

    # rres1 = TaperedClawedMeanderReadout(
    #     total_length=6186μm,
    #     coupling_length=470μm,
    #     coupling_gap=5μm,
    #     bend_radius=50μm,
    #     n_meander_turns=7,
    #     total_height=1600μm, # from top hook to bottom hook
    #     hanger_length=400μm,
    #     gap_claw=0.8μm,
    #     α_claw=20°,
    #     taper_style=Paths.CPW(1.0μm, 0.8μm)
    # )

    # rres2 = TaperedClawedMeanderReadout(
    #     total_length=6079μm,
    #     coupling_length=250μm,
    #     coupling_gap=5μm,
    #     bend_radius=50μm,
    #     n_meander_turns=7,
    #     total_height=1600μm, # from top hook to bottom hook
    #     hanger_length=400μm,
    #     gap_claw=0.8μm,
    #     α_claw=20°,
    #     taper_style=Paths.CPW(1.0μm, 0.8μm)
    # )

    rres3 = TaperedClawedMeanderReadout(
        total_length=5976μm,
        coupling_length=130μm,
        coupling_gap=5μm,
        bend_radius=50μm,
        n_meander_turns=7,
        total_height=1600μm, # from top hook to bottom hook         #######change to
        hanger_length=400μm,                   ################
        gap_claw=0.8μm,
        α_claw=20°,
        taper_style=Paths.CPW(1.0μm, 0.8μm)
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
        α_claw=20°,
        taper_style=Paths.CPW(1.0μm, 0.8μm)
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
        α_claw=20°,
        taper_style=Paths.CPW(1.0μm, 0.8μm)
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
        α_claw=20°,
        taper_style=Paths.CPW(1.0μm, 0.8μm)
    )

    # rres_node1 = add_node!(g, rres1)
    # rres_node2 = add_node!(g, rres2)
    rres_node3 = add_node!(g, rres3)
    rres_node4 = add_node!(g, rres4)
    rres_node5 = add_node!(g, rres5)
    rres_node6 = add_node!(g, rres6)

    # rres_node3_2 = add_node!(g, rres3)
    # rres_node4_2 = add_node!(g, rres4)
    # rres_node5_2 = add_node!(g, rres5)
    # rres_node6_2 = add_node!(g, rres6)


    # attach!(g, p_feedline_node, rres_node1 => :feedline, 1.25mm, i=4, location=-1)
    # attach!(g, p_feedline_node, rres_node2 => :feedline, 0.4mm, i=4, location=1)
    attach!(g, p_feedline_node, rres_node3 => :feedline, 0.5mm, i=4, location=-1)
    attach!(g, p_feedline_node, rres_node4 => :feedline, 1.1mm, i=4, location=1)
    attach!(g, p_feedline_node, rres_node5 => :feedline, 1.7mm, i=4, location=-1)     #### from 3.25 to (0.5mm spacing)
    attach!(g, p_feedline_node, rres_node6 => :feedline, 2.3mm, i=4, location=1)


    # attach!(g, p_xye_node=> :resonator, rres_node3_2 => :qubit, 0.5mm, i=4, location=-1)

    fuse!(g, p_xye_node1 => :resonator, rres_node3 => :qubit)
    fuse!(g, p_xye_node2 => :resonator, rres_node4 => :qubit)
    fuse!(g, p_xye_node3 => :resonator, rres_node5 => :qubit)
    fuse!(g, p_xye_node4 => :resonator, rres_node6 => :qubit)

    return g
end

function TransmissionLine(g)
    p_feedline = Path(Point(-1400μm, 0μm) - Point(650μm, 0μm); α0=0, metadata=LayerVocabulary.METAL_NEGATIVE) # 650μm is the length of the launcher  #-2350 to -1000
    sty = launch!(p_feedline)
    straight!(p_feedline, 2800μm, sty)        #######from 4700 to 2800
    launch!(p_feedline)
    p_feedline_node = add_node!(g, p_feedline)
    return g, p_feedline_node
end








# Feedline Component
@compdef struct xy_electrode_line <: Component
    name        = "xy_electrode_line"
    taper_len   = 50μm    # Taper transition length
    taper_gap   = 1μm
    taper_trace = 2μm
    trace       = 6μm     # Trace width
    gap         = 4μm     # CPW gap
    bend_radius = 50μm    # Bend radius
    seg_len1     = 100μm   # Straight section length
    seg_len2     = 200μm   # Straight section length
    seg_len3     = 100μm   # Straight section length
    path_point1 =0μm
    path_point2 =1μm
    hook_point1 =0μm            ######- means + y 
    hook_point2 =1050μm
    α0=90°
    α1=90°
    α2=-90°
    α3=-90°
end



function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, cf::xy_electrode_line)
    params = parameters(cf)

    # 1) Initialize path
    path = Path(Point(params.path_point1, params.path_point2), α0=params.α0)
    
    # 2) Left port
    sty = launch!(path)

    # 3) First straight segment
    straight!(path, params.seg_len1, sty)
    
    # 4)  meander
    turn!(path, params.α1, params.bend_radius)
    straight!(path, params.seg_len2, sty)
    turn!(path, params.α2, params.bend_radius)
    straight!(path, params.seg_len3, sty)

    # 5) taper

    straight!(path, params.taper_len, Paths.Taper())    

    final_cpw = Paths.SimpleCPW(params.taper_trace, params.taper_gap)
    # straight!(path, 0μm, final_cpw)
    # Final short straight segment
    straight!(path, 40μm, final_cpw)
    # straight!(path, 0μm, Paths.CPW(0μm, params.taper_gap; termination = :open))
    terminate!(path; gap=params.taper_gap)

    render!(cs, path, GDSMeta(3, 0))


    return cs
end

function SchematicDrivenLayout.hooks(cf::xy_electrode_line)
    params = parameters(cf)
    resonator_hook = PointHook(Point(params.hook_point1, params.hook_point2), params.α3)
    return (;resonator=resonator_hook)
end




function xy_electrode_line(g)
    p_xy_electrode_line1 = xy_electrode_line(   

        taper_len   = 50μm,    # Taper transition length
        taper_gap   = 1μm,
        taper_trace = 2μm,
        trace       = 6μm ,    # Trace width
        gap         = 4μm ,    # CPW gap
        bend_radius = 50μm ,   # Bend radius
        seg_len1     = 100μm ,  # Straight section length
        seg_len2     = 200μm,   # Straight section length
        seg_len3     = 150μm ,  # Straight section length
        path_point1 =0μm,
        path_point2 =1μm,
        hook_point1 =-215μm,
        hook_point2 =1150μm,
        α0=90°,
        α1=90°,
        α2=-90°,
        α3=90°
    )

    p_xy_electrode_line2 = xy_electrode_line(   

        taper_len   = 50μm,    # Taper transition length
        taper_gap   = 1μm,
        taper_trace = 2μm,
        trace       = 6μm ,    # Trace width
        gap         = 4μm ,    # CPW gap
        bend_radius = 50μm ,   # Bend radius
        seg_len1     = 700μm ,  # Straight section length
        seg_len2     = 200μm,   # Straight section length
        seg_len3     = 150μm ,  # Straight section length
        path_point1 =0μm,
        path_point2 =1μm,
        hook_point1 =-215μm,
        hook_point2 =-1750μm,
        α0=-90°,
        α1=-90°,
        α2=90°,
        α3=90°
    )

    p_xy_electrode_line3 = xy_electrode_line(   

        taper_len   = 50μm,    # Taper transition length
        taper_gap   = 1μm,
        taper_trace = 2μm,
        trace       = 6μm ,    # Trace width
        gap         = 4μm ,    # CPW gap
        bend_radius = 50μm ,   # Bend radius
        seg_len1     = 700μm ,  # Straight section length
        seg_len2     = 200μm,   # Straight section length
        seg_len3     = 150μm ,  # Straight section length
        path_point1 =0μm,
        path_point2 =1μm,
        hook_point1 =-215μm,
        hook_point2 =-1750μm,
        α0=-90°,
        α1=-90°,
        α2=90°,
        α3=90°
    )

    p_xy_electrode_line4 = xy_electrode_line(   

        taper_len   = 50μm,    # Taper transition length
        taper_gap   = 1μm,
        taper_trace = 2μm,
        trace       = 6μm ,    # Trace width
        gap         = 4μm ,    # CPW gap
        bend_radius = 50μm ,   # Bend radius
        seg_len1     = 100μm ,  # Straight section length
        seg_len2     = 200μm,   # Straight section length
        seg_len3     = 150μm ,  # Straight section length
        path_point1 =0μm,
        path_point2 =1μm,
        hook_point1 =-215μm,
        hook_point2 =1150μm,
        α0=90°,
        α1=90°,
        α2=-90°,
        α3=90°
    )
    p_xye_node1 = add_node!(g, p_xy_electrode_line1)
    p_xye_node2 = add_node!(g, p_xy_electrode_line2)
    p_xye_node3 = add_node!(g, p_xy_electrode_line3)
    p_xye_node4 = add_node!(g, p_xy_electrode_line4)

    return g, p_xye_node1,p_xye_node2,p_xye_node3,p_xye_node4
end









g = assemble_schematic_graph()

@time "Floorplanning" floorplan = plan(g)
# Chip
center_xyz = DeviceLayout.center(floorplan)
chip = centered(Rectangle(5mm, 5mm), on_pt=Point(0mm, 0mm))   #### from 7 to 5
# Define rectangle that gets extruded to generate substrate volume
render!(floorplan.coordinate_system, chip, LayerVocabulary.CHIP_AREA)

check!(floorplan)

unit_chip = Cell("unit_chip") # "unit_chip" = "pattern used for fabrication"
@time "Rendering to polygons" render!(unit_chip, floorplan, ASSEMBLY_TARGET)
#render!(g, identity, strict=:no, simulation=true)
flatten!(unit_chip)

# Assemble into a larger 2x2 sample
full_chip = Cell("full_chip")
push!(full_chip.refs, CellArray(unit_chip, Point(0μm, 0μm), dr=Point(0mm, -5mm), dc=Point(5mm, 0mm), nr=2, nc=2))         ######from  7 to 5
flatten!(full_chip)

# add chip markups
chip_markings = Cell(uniquename("chip_markup"))
PolyText.polytext!(chip_markings, "CQED Lab @ UW\nSlime Jr v3\nTa/Nb S1", DotMatrix(; pixelsize=12μm, rounding=4μm))         #########from v1 to v3
push!(full_chip.refs, CellReference(chip_markings, Point(-2.2mm, -1.8mm)))

chip_markings = Cell(uniquename("chip_markup"))
PolyText.polytext!(chip_markings, "CQED Lab @ UW\nSlime Jr v3\nTa/Nb S2", DotMatrix(; pixelsize=12μm, rounding=4μm))  #####from 16 to 12,6 to 4
push!(full_chip.refs, CellReference(chip_markings, Point(2.8mm, -1.8mm)))          ######### left corner

chip_markings = Cell(uniquename("chip_markup"))
PolyText.polytext!(chip_markings, "CQED Lab @ UW\nSlime Jr v3\nTa/Nb S3", DotMatrix(; pixelsize=12μm, rounding=4μm))
push!(full_chip.refs, CellReference(chip_markings, Point(-2.2mm, -6.8mm)))

chip_markings = Cell(uniquename("chip_markup"))
PolyText.polytext!(chip_markings, "CQED Lab @ UW\nSlime Jr v3\nTa/Nb S4", DotMatrix(; pixelsize=12μm, rounding=4μm))
push!(full_chip.refs, CellReference(chip_markings, Point(2.8mm, -6.8mm)))

# add dicing cross
dicing_marker = Cell(uniquename("dicing_marker"))
render!(dicing_marker, centered(Rectangle(1mm, 0.1mm)))
render!(dicing_marker, centered(Rectangle(0.1mm, 1mm)))
push!(full_chip.refs, CellArray(dicing_marker, Point(-2.5mm, 2.5mm), dr=Point(0mm, -5mm), dc=Point(5mm, 0mm), nr=3, nc=3))         ############from 3.5 to 2.5 7 to5

flatten!(full_chip)



# save("D:/templ/Slime_Jr_PNNL_v2_Ta.gds", full_chip)

# save(joinpath(@__DIR__, "Slime_Jr_PNNL_v2_Ta.gds"), full_chip)

save(raw"C:\Users\c\Desktop\Slime_Jr_PNNL_v2_Ta.gds", full_chip)