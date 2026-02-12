using Pkg
Pkg.activate(".")  # ensures the environment is used
using FileIO, DeviceLayout, DeviceLayout.PreferredUnits, DeviceLayout.SchematicDrivenLayout
import DeviceLayout: μm, nm
import DeviceLayout: uconvert
import DeviceLayout: flushtop, flushleft, flushright, below, above
using CQEDPDK
import CQEDPDK.LAYER_RECORD
using CQEDPDK.ChipTemplates_CQED

# define layers
MECHANICS_LAYER = 3
HF_HOLES_LAYER = 3
UC_LAYER = 6
BANDAID_LAYER = 9
BRIDGE_FEET_LAYER = 9
NO_HOLE_LAYER = 20
JJ_MEMBRANE_LAYER = 21
GND_CUTOUT_LAYER = 22

# Define the chip dimensions
chip_height = 5mm
chip_width = 5mm
deadzone_width = 0.15mm
deadzone_height = 0.15mm
die_height = 2mm
die_width = 2mm

# define baseline dimensions for mechanics
ca = 534nm
ct = 123nm
ch = 422nm

cpw_width = 10μm
cpw_gap = 6μm
PATH_STYLE = Paths.SimpleCPW(cpw_width, cpw_gap)

function PhS_unitcell_asym(c, ca=534nm, ctx=ct, cty=ct, chx=ch, chy=ch)
    #r0 = Rectangle(Point(-ca/2, -ca/2), Point(ca/2, ca/2))
    r1 = Rectangle(Point(-ctx / 2, -chy / 2), Point(ctx / 2, chy / 2))
    r2 = Rectangle(Point(-chx / 2, -cty / 2), Point(chx / 2, cty / 2))

    u = Polygons.union2d(r2, r1)
    render!(c, u, GDSMeta(MECHANICS_LAYER))
end

function add_global_marker!(dev)
    # Elionix recognizable global markers
    marker = Cell(uniquename("global_marker"))
    r1 = Rectangle(Point(-10µm, 10µm), Point(10µm, 150µm))     # up
    r2 = Rectangle(Point(-10µm, -150µm), Point(10µm, -10µm))    # down (fixed) 
    r3 = Rectangle(Point(-150µm, -10µm), Point(-10µm, 10µm))    # left (fixed)
    r4 = Rectangle(Point(10µm, -10µm), Point(150µm, 10µm))     # right
    r5 = Rectangle(Point(-0.25µm, -10µm), Point(0.25µm, 10µm))
    r6 = Rectangle(Point(-10µm, -0.25µm), Point(10µm, 0.25µm))
    render!(marker, (r1, r2, r3, r4, Polygons.union2d(r5, r6)), LAYER_RECORD.marker)

    block = Cell(uniquename("global_marker_block"))
    push!(block.refs, CellArray(marker, Point(-6mm, -0.5mm), dr=Point(12mm, 0mm), dc=Point(0mm, 0.5mm), nr=2, nc=3))
    flatten!(block)  # make outer replication reliable/visible

    push!(dev.refs, CellArray(block, Point(0mm, -6mm), dr=Point(0mm, 4mm), dc=Point(0mm, 0mm), nr=4, nc=1))
    return dev
end

function add_local_marker(die)
    # add local markers
    # layer
    local_marker = Cell(uniquename("local_marker"))
    r = Polygons.union2d(centered(Rectangle(0.1mm, 0.02mm)), centered(Rectangle(0.02mm, 0.1mm)))
    render!(local_marker, r, LAYER_RECORD.marker)
    push!(die.refs, CellArray(local_marker, Point(-0.2mm, 0.2mm), dr=Point(0mm, -0.4mm), dc=Point(0.4mm, 0mm), nr=2, nc=2))
end

function add_chip_signature(dev)
    chip_signature = Cell(uniquename("chip_markup"))
    PolyText.polytext!(chip_signature, "ZEP cal SOI\nCQED Lab @ UW", DotMatrix(; pixelsize=25μm, rounding=6μm))
    push!(dev.refs, CellReference(chip_signature, Point(-4.5mm, -5.5mm)))
end

function add_chip_triangle(dev)
    triangle = Cell(uniquename("triangle"))
    render!(triangle, Polygon(Point(-525µm / 2, 0µm), Point(525µm / 2, 0µm), Point(0µm, 750µm)), LAYER_RECORD.marker)
    push!(dev.refs, CellReference(triangle, Point(-4.5mm, -5mm)))
    return dev
end

function add_dicing_cross(dev)
    # add dicing cross
    dicing_marker = Cell(uniquename("dicing_marker"))

    r = Polygons.union2d(centered(Rectangle(0.5mm, 0.05mm)), centered(Rectangle(0.05mm, 0.5mm)))
    render!(dicing_marker, r, LAYER_RECORD.marker)
    # top two
    push!(dev.refs, CellArray(dicing_marker, Point(-4mm, -4mm), dr=Point(0mm, die_height), dc=Point(die_width, 0mm), nr=5, nc=5))
    # bottom right (left side is for chip signature)
    push!(dev.refs, CellArray(dicing_marker, Point(1.5mm, -1.5mm), dr=Point(0mm, -3mm), dc=Point(3mm, 0mm), nr=1, nc=1))
end

function build_transmission_line()
    (ptL, αL) = ChipTemplates_CQED.launcher_site(16)
    (ptR, αR) = ChipTemplates_CQED.launcher_site(5)

    readout_length = hypot(ptR.x - ptL.x, ptR.y - ptL.y) - 650μm * 2 # length of launcher is 650μm

    TL_path = Path(
        ptL + Point(150.0μm, 0.0μm), # 150μm is the "gap" behind the bonding pad
        α0=αL,
        name="p_ro",
        metadata=LAYER_RECORD.metal_negative
    )
    sty = launch!(TL_path; extround=50.0μm, trace0=300.0μm,
        trace1=10.0μm, gap0=150.0μm, gap1=6.0μm, flatlen=250.0μm,
        taperlen=250.0μm)
    straight!(TL_path, readout_length / 2, PATH_STYLE)
    straight!(TL_path, readout_length / 2, PATH_STYLE)
    launch!(TL_path)
    return TL_path
end

function SimpleDolanJunction(; w_jj=0.3μm, h_jj=0.14μm, h_ground_island=20μm, h_excess=2μm, w_pad_bot=2μm, w_pad_top=2μm, L_taper=1μm, L_finger=1μm)
    jj = Cell(uniquename("jj"), nm)
    # simulation geometry
    jj_rect = centered(Rectangle(w_jj, h_jj))
    top_lead = Align.above(Rectangle(w_pad_top, (h_ground_island - h_jj) / 2 + h_excess), jj_rect; centered=true)
    ### bottom lead
    bottom_lead = Align.below(Polygon(
            Point(-w_pad_bot / 2, -h_ground_island / 2 - h_excess),
            Point(-w_pad_bot / 2, -h_jj / 2 - L_finger - L_taper),
            Point(-w_jj / 2, -h_jj / 2 - L_finger),
            Point(-w_jj / 2, -h_jj / 2),
            Point(w_jj / 2, -h_jj / 2),
            Point(w_jj / 2, -h_jj / 2 - L_finger),
            Point(w_pad_bot / 2, -h_jj / 2 - L_finger - L_taper),
            Point(w_pad_bot / 2, -h_ground_island / 2 - h_excess)
        ), jj_rect; centered=true)
    render!(jj, jj_rect, LAYER_RECORD.junction_pattern)
    render!(jj, top_lead, LAYER_RECORD.junction_pattern)
    render!(jj, bottom_lead, LAYER_RECORD.junction_pattern)
    return jj
end

function make_SQUID(; w_jj1=0.3μm, h_jj1=0.14μm, w_jj2=0.3μm, h_jj2=0.14μm, h_ground_island=20μm, h_excess=2μm, w_pad_bot=2μm, w_pad_top=2μm, L_taper=1μm, L_finger=1μm, w_squid=10μm)
    asquid = Cell(uniquename("asymmetric squid"), nm)
    # simulation geometry
    jj1 = SimpleDolanJunction(; w_jj=w_jj1, h_jj=h_jj1, h_ground_island=h_ground_island, h_excess=h_excess, w_pad_bot=w_pad_bot, w_pad_top=w_pad_top, L_taper=L_taper, L_finger=L_finger)
    jj2 = SimpleDolanJunction(; w_jj=w_jj2, h_jj=h_jj2, h_ground_island=h_ground_island, h_excess=h_excess, w_pad_bot=w_pad_bot, w_pad_top=w_pad_top, L_taper=L_taper, L_finger=L_finger)

    push!(asquid.refs, CellReference(jj1, Point(-w_squid / 2, zero(w_squid))))
    push!(asquid.refs, CellReference(jj2, Point(w_squid / 2, zero(w_squid))))

    return asquid
end

function claw_cpl(; w_shield=2μm, w_claw=32μm, l_claw=160μm, claw_gap=6μm, w_grasp=84μm, arm_trace=10μm)
    claw_cpl = Cell(uniquename("claw_cpl"), nm)
    claw_hole1 = centered(Rectangle(arm_trace, claw_gap))
    claw_hole2 =
        Rectangle(w_grasp + 2 * w_shield + 4 * claw_gap + 2 * w_claw, w_claw + 2 * claw_gap)
    claw_hole2 = flushtop(claw_hole2, claw_hole1, centered=true)

    claw_hole3 = Rectangle(w_claw + 2 * claw_gap, w_shield + l_claw + claw_gap)
    claw_hole3 = flushleft(below(claw_hole3, claw_hole2), claw_hole2)

    claw_hole4 = flushright(claw_hole3, claw_hole2)

    claw1 = Rectangle(arm_trace, claw_gap)
    claw1 = flushtop(claw1, claw_hole1, centered=true)

    claw2 = Rectangle(w_grasp + 2 * w_shield + 2 * claw_gap + 2 * w_claw, w_claw)
    claw2 = below(claw2, claw1, centered=true)

    claw3 = Rectangle(w_claw, claw_gap + w_shield + l_claw)
    claw3 = flushleft(below(claw3, claw2), claw2)

    claw4 = flushright(claw3, claw2)

    claw = difference2d(
        [claw_hole1, claw_hole2, claw_hole3, claw_hole4],
        [claw1, claw2, claw3, claw4]
    )
    render!(claw_cpl, claw + Point(0μm, w_claw + claw_gap * 1.5 + w_shield * 1), LAYER_RECORD.metal_negative) # move the 
    return claw_cpl
end

function qubit_cap(; cap_width=24μm, cap_length=520μm, cap_gap=30μm, junction_gap=20.0μm, island_rounding=0μm)
    qubit_cap = Cell(uniquename("qubit_cap"), nm)

    # Capacitor metal
    qubitIsland = Rectangle(Point(-cap_width / 2, cap_length + junction_gap / 2), Point(cap_width / 2, junction_gap / 2))

    # Capacitor ground
    gapFill = Rectangle(Point(-cap_width / 2 - cap_gap, cap_length + junction_gap / 2 + cap_gap),
        Point(cap_width / 2 + cap_gap, -junction_gap / 2))

    diff = Rounded(island_rounding)(difference2d(gapFill, qubitIsland))

    render!(qubit_cap, diff, LAYER_RECORD.metal_negative)
    push!(qubit_cap.refs, CellReference(qubit_island, Point(0μm, 0μm)))

    claw = claw_cpl()
    push!(qubit_cap.refs, CellReference(claw, Point(0μm, cap_length + cap_gap + junction_gap / 2)))

    return qubit_cap
end

function make_qubit_cell(;)
    Qubit_cell = Cell(uniquename("Qubit_cell"), nm)
    qubit_island = qubit_cap()
    jj = make_SQUID()

    # the JJs/SQUID
    push!(Qubit_cell.refs, CellReference(qubit_island, Point(0μm, 0μm)))
    push!(Qubit_cell.refs, CellReference(jj, Point(0μm, 0μm), rot=0))
    flatten!(Qubit_cell)
    return Qubit_cell
end

function create_resonator(style, p0; total_length=5000μm, coupling_length=200μm, coupling_gap=5μm, bend_radius=50μm, n_meander_turns=5, total_height=1350μm, hanger_length=500μm)
    path = Path(
        p0 + Point(-coupling_length / 2, -coupling_gap - style.gap * 2 - style.trace),
        α0=0°,
    )

    n_bends = 3 + 2 * n_meander_turns # nμmber of 90 degree bends
    arm_length = (
        total_height - hanger_length - n_bends * bend_radius - coupling_gap - style.gap - style.trace / 2 - w_shield - 2 * claw_gap - w_claw
    )
    # Length of straight sections in meander
    straight_length =
        (
            total_length - 3 * coupling_length / 2 - n_bends * pi * bend_radius / 2 -
            arm_length - hanger_length
        ) / n_meander_turns

    straight!(path, coupling_length, style)
    turn!(path, -90°, bend_radius)
    straight!(path, hanger_length)
    #attach!(path, CoordinateSystemReference(bridge), hanger_length / 2)
    turn!(path, -90°, bend_radius)
    # Center of the straight section of meander lines up with coupling midpoint (and claw)
    straight!(path, straight_length / 2 + coupling_length / 2)
    turn!(path, 180°, bend_radius)

    # Start the meander with a full straight section
    meander_length =
        (n_meander_turns - 1) * (straight_length + pi * bend_radius) + straight_length / 2 -
        bend_radius
    meander!(path, meander_length, straight_length, bend_radius, -180°)
    turn!(path, -90°, bend_radius)
    straight!(path, arm_length)
    #attach!(path, CoordinateSystemReference(bridge), arm_length / 2)
    #turn!(path, -pi/2, turnRadRes, cpw_style)
    #straight!(path, L2, cpw_style)
    #qubit = make_qubit_cell()
    #attach!(path, CellReference(qubit), pathlength(path[end]))
    return path
end

# function for Z path
function generate_Zline_instructions!(path, style, instructions)
    # 'straight' instructions are parameterized by the length of straight cpw to
    #     append
    # 'turn' instructions are parameterized by the angle to turn and the radius of
    #     the turn
    for instruction in instructions
        if instruction[1] == "straight"
            straight!(path, instruction[2], style)
        elseif instruction[1] == "turn"
            turn!(path, instruction[2], instruction[3], style)
        elseif instruction[1] == "endZ"
            straight!(path, 200μm, Paths.Taper())
            straight!(path, 100μm, Paths.CPW(3.3μm, 2.0μm))
            straight!(path, 50μm)
            flux_bias_cell = Cell(uniquename("flux_bias"), nm)
            flux_bias!(flux_bias_cell, "r", 6.35μm, 2μm, 4.35μm, 3.3μm, 2μm) # flux_over, flux_under, flux_cut, z_trace, z_gap,
            flux_bias_cell_ref = CellReference(flux_bias_cell, Point(0μm, 0μm), rot=-pi / 2)
            attach!(path, flux_bias_cell_ref, 50μm, i=length(path))
        end
    end
end

function flux_bias!(c::Cell{T}, dir, flux_over, flux_under, flux_cut, z_trace, z_gap) where {T}

    mx, mn = max(flux_over, flux_under), min(flux_over, flux_under)
    if dir == "l"
        flux_over, flux_under, flux_cut, z_trace, z_gap, mx, mn =
            -flux_over, -flux_under, -flux_cut, -z_trace, -z_gap, -mx, -mn
    end
    abs_gap = abs(z_gap)
    abs_trace = abs(z_trace)

    ground = Rectangle(Point(-flux_cut - z_gap - z_trace / 2, zero(T)),
        Point(z_trace / 2 + z_gap + mx, 2 * abs_gap + abs_trace))
    belowcut = Rectangle(Point(-flux_cut - z_gap - z_trace / 2, zero(T)),
        Point(-z_gap - z_trace / 2, abs_trace + abs_gap))
    trace = Rectangle(Point(-z_trace / 2, zero(T)),
        Point(z_trace / 2, abs_trace + abs_gap))
    tap = Rectangle(Point(z_trace / 2, abs_gap),
        Point(z_trace / 2 + z_gap + mn, abs_trace + abs_gap))

    #result = clip(Clipper.ClipTypeDifference, [ground], [belowcut])
    #result = clip(Clipper.ClipTypeDifference, result, [trace])
    #result = clip(Clipper.ClipTypeDifference, result, [tap])
    result = difference2d(
        [ground],
        [belowcut, trace, tap]
    )

    if flux_under != flux_over
        if abs(flux_under) > abs(flux_over)
            fill = Rectangle(Point(z_trace / 2 + z_gap + mn, abs_gap),
                Point(z_trace / 2 + z_gap + mx, abs_trace + 2 * abs_gap))
        end
        if abs(flux_over) > abs(flux_under)
            fill = Rectangle(Point(z_trace / 2 + z_gap + mn, zero(T)),
                Point(z_trace / 2 + z_gap + mx, abs_trace + abs_gap))
        end
        result = difference2d(result, fill)
        #result = clip(Clipper.ClipTypeDifference, result, [fill])
    end

    render!(c, result, LAYER_RECORD.metal_negative)
end

function generate_XYline_instructions!(path, hole_path, style, instructions)
    # 'straight' instructions are parameterized by the length of straight cpw to
    #     append
    # 'turn' instructions are parameterized by the angle to turn and the radius of
    #     the turn
    for instruction in instructions
        if instruction[1] == "straight1"
            straight!(path, instruction[2], style)
            straight!(hole_path, instruction[2], cpw_blank)
        elseif instruction[1] == "turn"
            turn!(path, instruction[2], instruction[3])
            straight!(path, 200μm)
            turn!(hole_path, instruction[2], instruction[3], cpw_blank)
            straight!(hole_path, 200μm, cpw_blank)
            #straight!(hole_path, instruction[3], cpw_blank)
            #turn!(hole_path, instruction[2], 1nm, cpw_blank)
            #straight!(hole_path, instruction[3], cpw_blank)
        elseif instruction[1] == "straight2"
            straight!(path, instruction[2])
            straight!(hole_path, instruction[2], cpw_blank)
        elseif instruction[1] == "endXY"
            straight!(path, 200μm, Paths.Taper())
            straight!(path, 100μm, Paths.CPW(13μm, 1μm))
            straight!(path, 2μm, Paths.Trace(15μm))
            straight!(hole_path, 300μm, cpw_blank)
        end
    end
end

function main()
    w_shield = 2μm
    w_claw = 32μm
    l_claw = 160μm
    claw_gap = 6μm
    w_grasp = 84μm
    arm_trace = 10μm
    cap_width = 24μm
    cap_length = 520μm
    cap_gap = 30μm
    junction_gap = 20.0μm
    island_rounding = 0μm

    cpw_style = Paths.SimpleCPW(10µm, 6μm)
    # Chip
    device = Cell("device", nm)

    device = ChipTemplates_CQED.build_device!(device;
        chip_width=chip_width,
        chip_height=chip_height,
        deadzone_width=deadzone_width,
        deadzone_height=deadzone_height
    )
    TL_path = build_transmission_line()
    #add_global_marker!(device)
    #add_chip_triangle(device)
    #add_local_marker(device)
    #add_chip_signature(device)
    #add_dicing_cross(device)
    #add_mechanics_test_pattern(device)

    render!(device, TL_path, LAYER_RECORD.metal_negative)

    (ptL, αL) = ChipTemplates_CQED.launcher_site(16)

    RO1_path = create_resonator(cpw_style, ptL + Point(1500µm, 0μm))
    render!(device, RO1_path, LAYER_RECORD.metal_negative)

    qubit = make_qubit_cell()
    p_end = Paths.p1(RO1_path)
    α_end = Paths.α1(RO1_path)               # replace with your actual endpoint function
    push!(device.refs, CellReference(qubit, p_end - Point(0μm, junction_gap / 2 + cap_length + cap_gap + w_shield + w_claw + claw_gap * 2), rot=0))

    # Z line
    (ptZ1, αZ1) = ChipTemplates_CQED.launcher_site(11)
    Z1_path = Path(ptZ1 + Point(0µm, 150µm), α0=αZ1)
    launch!(Z1_path;)
    Z1_instructions = [
        ["straight", 200μm - 59.519μm],
        ["turn", pi / 6, 500μm],
        ["straight", 282μm],
        ["turn", -pi / 6, 500μm],
        ["straight", 50μm],
        ["endZ"]
    ]
    generate_Zline_instructions!(Z1_path, cpw_style, Z1_instructions)
    render!(device, Z1_path, LAYER_RECORD.metal_negative)
    save(joinpath(@__DIR__, "FUN17_CQED.gds"), device)
end

# run the code
main()

