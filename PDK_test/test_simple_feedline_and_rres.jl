using Pkg
Pkg.activate(".")  # ensures the environment is used
using FileIO, CSV, DataFrames, JSON, JSONSchema
using DeviceLayout, DeviceLayout.PreferredUnits, DeviceLayout.SchematicDrivenLayout
import DeviceLayout: μm, nm
import .SchematicDrivenLayout.ExamplePDK
import .SchematicDrivenLayout.ExamplePDK: LayerVocabulary, L1_TARGET, add_bridges!
using .ExamplePDK.Transmons, .ExamplePDK.ReadoutResonators
import .ExamplePDK.SimpleJunctions: ExampleSimpleJunction
import DeviceLayout: uconvert

using PRIMA

function TransmissionLine()
    p = Path(Point(-2000μm, 0μm), α0 = 0)
    sty = launch!(p)
    straight!(p, 4000μm, sty)
    launch!(p)
    tl = Cell(uniquename("transmissionline"), nm)
    tl = render!(tl, p, GDSMeta(0))
    
end

function single_transmon(;
    w_shield=2μm,
    claw_gap=6μm,
    w_claw=32μm,
    l_claw=160μm,
    cap_width=24μm,
    cap_length=620μm,
    cap_gap=30μm,
    total_length=5000μm,
    n_meander_turns=5,
    hanger_length=500μm,
    bend_radius=50μm,
    save_gds::Bool=true
)
    #### Reset name counter for consistency within a Julia session
    reset_uniquename!()

    #### Assemble schematic graph
    ### Compute additional/implicit parameters
    cpw_width = 10μm
    cpw_gap = 6μm
    PATH_STYLE = Paths.SimpleCPW(cpw_width, cpw_gap)
    BRIDGE_STYLE = ExamplePDK.bridge_geometry(PATH_STYLE)
    coupling_gap = 5μm
    w_grasp = cap_width + 2 * cap_gap
    arm_length = 428μm # straight length from meander exit to claw
    total_height =
        arm_length +
        coupling_gap +
        Paths.extent(PATH_STYLE) +
        hanger_length +
        (3 + n_meander_turns * 2) * bend_radius
    ### Create abstract components
    ## Transmon
    qubit = ExampleRectangleTransmon(;
        jj_template=ExampleSimpleJunction(),
        name="qubit",
        cap_length,
        cap_gap,
        cap_width
    )
    ## Resonator
    rres = ExampleClawedMeanderReadout(;
        name="rres",
        coupling_length=400μm,
        coupling_gap,
        total_length,
        w_shield,
        w_claw,
        l_claw,
        claw_gap,
        w_grasp,
        n_meander_turns,
        total_height,
        hanger_length,
        bend_radius,
        bridge=BRIDGE_STYLE
    )
    ## Readout path
    readout_length = 2700μm
    p_readout = Path(
        Point(0μm, 0μm);
        α0=π / 2,
        name="p_ro",
        metadata=LayerVocabulary.METAL_NEGATIVE
    )
    straight!(p_readout, readout_length / 2, PATH_STYLE)
    straight!(p_readout, readout_length / 2, PATH_STYLE)

    #### Build schematic graph
    g = SchematicGraph("single-transmon")
    qubit_node = add_node!(g, qubit)
    rres_node = fuse!(g, qubit_node, rres)
    # Equivalent to `fuse!(g, qubit_node=>:readout, rres=>:qubit)`
    # because `matching_hooks` was implemented for that component pair
    p_readout_node = add_node!(g, p_readout)

    ## Attach resonator to feedline
    # Instead of `fuse!` we use a schematic-based `attach!` method to place it along the path
    # Syntax is a mix of `fuse!` and how we attached the ports above
    attach!(g, p_readout_node, rres_node => :feedline, 0mm, location=1)

    #### Create the schematic (position the components)
    floorplan = plan(g)
    add_bridges!(floorplan, BRIDGE_STYLE, spacing=300μm) # Add bridges to paths

    #### Prepare solid model
    # Specify the extent of the simulation domain.
    substrate_x = 5mm
    substrate_y = 5mm

    center_xyz = DeviceLayout.center(floorplan)
    chip = centered(Rectangle(substrate_x, substrate_y), on_pt=center_xyz)
    
    # Define rectangle that gets extruded to generate substrate volume
    render!(floorplan.coordinate_system, chip, LayerVocabulary.CHIP_AREA)

    check!(floorplan)

    if save_gds
        # Render to GDS as well, may be useful to debug SolidModel generation
        c = Cell("single_transmon", nm)
        # Use simulation=true to render simulation-only geometry, `strict=:no` to continue from errors
        render!(c, floorplan, L1_TARGET, strict=:no, simulation=true)
        flatten!(c)
        save(joinpath(@__DIR__, "single_transmon.gds"), c)
    end
    return c
end

function main()
    # my cad code goes here: do all of the things
    c = single_transmon()
    #tl = TransmissionLine()
    #return save("test.gds", tl);
    
end

main() # execute main() at end of script.
