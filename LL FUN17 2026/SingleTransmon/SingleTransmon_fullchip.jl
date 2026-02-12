module SingleTransmon
# Using a module to let us cleanly include file in test script without worrying about namespaces

using FileIO, CSV, DataFrames, JSON, JSONSchema
using DeviceLayout, DeviceLayout.SchematicDrivenLayout, DeviceLayout.PreferredUnits
#import .SchematicDrivenLayout.ExamplePDK
#import .SchematicDrivenLayout.ExamplePDK: LayerVocabulary, L1_TARGET, add_bridges!
#using .ExamplePDK.Transmons, .ExamplePDK.ReadoutResonators
#import .ExamplePDK.SimpleJunctions: ExampleSimpleJunction
using CQEDPDK
using CQEDPDK.LayerVocabulary
import CQEDPDK: L1_TARGET, add_bridges!
using CQEDPDK.Transmons, CQEDPDK.ReadoutResonators
import CQEDPDK.SimpleJunctions: ExampleSimpleJunction, ExampleDolanJunction, ExampleDolanSQUID

import DeviceLayout: uconvert

using PRIMA

# ------------------------------------------------------------
# Launcher site helper
# ------------------------------------------------------------
"""
    launcher_site(id; L=5mm, n=4, c=925μm, e=200μm)

Return (pt, α0) for launcher site `id` in 1..16 on a square chip centered at (0,0).
α0 is the direction the feedline should initially point *into the chip*.

Numbering (n=4 per side):
1-4   top    (left→right)
5-8   right  (top→bottom)
9-12  bottom (right→left)
13-16 left   (bottom→top)

You can also call `launcher_site(side, k)` with side in (:top, :right, :bottom, :left)
and k in 1..n.
"""
function launcher_site(id::Integer; L=5mm, n::Int=4, c=925μm, e=200μm)
    @assert 1 <= id <= 4n "id must be in 1..$(4n)"

    S = L - 2c
    us = collect(range(-S / 2, S / 2; length=n))  # [-..., ..., +...]

    half = L / 2
    yT = +half - e
    yB = -half + e
    xR = +half - e
    xL = -half + e

    if 1 <= id <= n
        # -------------------------
        # TOP: left → right
        # -------------------------
        k = id
        return (Point(us[k], yT), -π / 2)

    elseif n < id <= 2n
        # -------------------------
        # RIGHT: top → bottom
        # -------------------------
        k = id - n
        return (Point(xR, us[end-k+1]), π)

    elseif 2n < id <= 3n
        # -------------------------
        # BOTTOM: right → left
        # -------------------------
        k = id - 2n
        return (Point(us[end-k+1], yB), +π / 2)

    else
        # -------------------------
        # LEFT: bottom → top
        # -------------------------
        k = id - 3n
        return (Point(xL, us[k]), 0.0)
    end
end

"""
    single_transmon(
        w_shield=2μm,
        claw_gap=6μm,
        w_claw=34μm,
        l_claw=121μm,
        cap_width=24μm,
        cap_length=620μm,
        cap_gap=30μm,
        total_length=5000μm,
        n_meander_turns=5,
        hanger_length=500μm,
        bend_radius=50μm,
        save_mesh::Bool=false,
        save_gds::Bool=false,
        mesh_order=2
    )

Generate a SolidModel and mesh for a single transmon design, using a rectangular transmon island and claw resonator.
"""
function single_transmon(;
    w_shield=2μm,
    claw_gap=6μm,
    w_claw=34μm,
    l_claw=121μm,
    cap_width=24μm,
    cap_length=620μm,
    cap_gap=30μm,
    total_length=5000μm,
    n_meander_turns=5,
    hanger_length=500μm,
    bend_radius=50μm,
    save_gds::Bool=false
)
    #### Reset name counter for consistency within a Julia session
    reset_uniquename!()

    #### Assemble schematic graph
    ### Compute additional/implicit parameters
    cpw_width = 10μm
    cpw_gap = 6μm
    PATH_STYLE = Paths.SimpleCPW(cpw_width, cpw_gap)
    BRIDGE_STYLE = CQEDPDK.bridge_geometry(PATH_STYLE)

    coupling_gap = 5μm
    w_grasp = cap_width + 2 * cap_gap

    arm_length = 428μm # straight length from meander exit to claw
    total_height =
        arm_length +
        coupling_gap +
        Paths.extent(PATH_STYLE) +
        hanger_length +
        (3 + n_meander_turns * 2) * bend_radius

    ###########################
    ## Transmon
    ###########################
    qubit = RectangleTransmon_Dolan(;
        jj_template=ExampleDolanSQUID(),
        name="qubit",
        cap_length,
        cap_gap,
        cap_width
    )

    ###########################
    ## Resonator
    ###########################
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

    ###########################
    # Feedline between launcher sites: left-2 -> right-2
    ###########################
    (ptL, αL) = launcher_site(15)
    (ptR, αR) = launcher_site(6)

    readout_length = hypot(ptR.x - ptL.x, ptR.y - ptL.y) - 650μm * 2 # length of launcher is 650μm

    p_readout = Path(
        ptL + Point(150.0μm, 0.0μm);
        α0=αL,
        name="p_ro",
        metadata=LayerVocabulary.METAL_NEGATIVE
    )
    sty = launch!(p_readout;)
    #extround=50.0μm, trace0=300.0μm,
    #trace1=10.0μm, gap0=150.0μm, gap1=6.0μm, flatlen=250.0μm,
    #taperlen=250.0μm)
    straight!(p_readout, readout_length / 2, PATH_STYLE)
    straight!(p_readout, readout_length / 2, PATH_STYLE)
    launch!(p_readout)

    # Readout lumped ports - squares on CPW trace, one at each end
    csport = CoordinateSystem(uniquename("port"), nm)
    render!(
        csport,
        only_simulated(centered(Rectangle(cpw_width, cpw_width))),
        LayerVocabulary.PORT
    )

    ######XY line
    ###################
    (ptxy1, αxy1) = launcher_site(12)

    p_xy1 = Path(
        ptxy1;
        α0=αxy1,
        name="p_xy1",
        metadata=LayerVocabulary.METAL_NEGATIVE
    )
    sty = launch!(p_xy1)
    straight!(p_xy1, 100μm, PATH_STYLE)
    launch!(p_xy1)

    #### Build schematic graph
    g = SchematicGraph("single-transmon")
    p_readout_node = add_node!(g, p_readout)

    qubit_node = add_node!(g, qubit)
    #rres_node = fuse!(g, qubit_node, rres)
    rres_node = fuse!(g, qubit_node => :readout, rres => :qubit)
    # Equivalent to `fuse!(g, qubit_node=>:readout, rres=>:qubit)`
    # because `matching_hooks` was implemented for that component pair

    ## Attach resonator to feedline
    # Instead of `fuse!` we use a schematic-based `attach!` method to place it along the path
    # Syntax is a mix of `fuse!` and how we attached the ports above
    attach!(g, p_readout_node, rres_node => :feedline, 0mm, i=5, location=1)

    #### Create the schematic (position the components)
    floorplan = plan(g)
    add_bridges!(floorplan, BRIDGE_STYLE, spacing=300μm) # Add bridges to paths

    #### Prepare solid model
    # Specify the extent of the simulation domain.
    substrate_x = 5mm
    substrate_y = 5mm

    #center_xyz = DeviceLayout.center(floorplan)
    #chip = centered(Rectangle(substrate_x, substrate_y), on_pt=center_xyz)
    #sim_area = centered(Rectangle(substrate_x, substrate_y), on_pt=center_xyz)
    chip = centered(Rectangle(substrate_x, substrate_y))
    sim_area = centered(Rectangle(substrate_x, substrate_y))

    # postrendering operations in solidmodel target define metal = (WRITEABLE_AREA - METAL_NEGATIVE) + METAL_POSITIVE
    render!(floorplan.coordinate_system, sim_area, LayerVocabulary.WRITEABLE_AREA)
    # Define rectangle that gets extruded to generate substrate volume
    render!(floorplan.coordinate_system, chip, LayerVocabulary.CHIP_AREA)

    render!(floorplan.coordinate_system, p_xy1, LayerVocabulary.METAL_NEGATIVE)
    check!(floorplan)

    if save_gds
        # Render to GDS as well, may be useful to debug SolidModel generation
        c = Cell("single_transmon", nm)
        # Use simulation=true to render simulation-only geometry, `strict=:no` to continue from errors
        render!(c, floorplan, L1_TARGET, strict=:no, simulation=true)
        flatten!(c)
        save(joinpath(@__DIR__, "single_transmon.gds"), c)
    end
    return
end

end # module