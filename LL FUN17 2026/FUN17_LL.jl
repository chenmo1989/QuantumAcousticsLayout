using Pkg
Pkg.activate(".")  # ensures the environment is used
using FileIO, DeviceLayout, DeviceLayout.PreferredUnits, DeviceLayout.SchematicDrivenLayout
import DeviceLayout: μm, nm
import DeviceLayout: uconvert
import DeviceLayout: flushtop, flushleft, flushright, below, above
using CQEDPDK
import CQEDPDK.LAYER_RECORD
using CQEDPDK.ChipTemplates_CQED
import .CQEDPDK: LayerVocabulary

## Define constants
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

etch_bias_LL = 450nm

cpw_style = Paths.SimpleCPW(10µm + 2 * etch_bias_LL, 6μm - 2 * etch_bias_LL)

launch_param = Dict(
    :extround => 0.0μm,
    :trace0 => 200.0μm,
    :trace1 => 10.0μm + etch_bias_LL * 2,
    :gap0 => 130.0μm,
    :gap1 => 6.0μm - etch_bias_LL * 2,
    :flatlen => 200.0μm,
    :taperlen => 150.0μm,
)

const GROUND_GRID = 50nm

w_shield = 2μm
w_claw = 35μm
l_claw = 160μm
claw_gap = 6μm
w_grasp = 84μm
arm_trace = 10μm
cap_width = 24μm
cap_length = 410μm
cap_gap = 30μm
junction_gap = 20.0μm
island_rounding = 0μm

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

function add_local_marker!(die)
    # add local markers
    # layer
    local_marker = Cell(uniquename("local_marker"))
    r = Polygons.union2d(centered(Rectangle(0.1mm, 0.02mm)), centered(Rectangle(0.02mm, 0.1mm)))
    render!(local_marker, r, LAYER_RECORD.marker)
    push!(die.refs, CellArray(local_marker, Point(-0.2mm, 0.2mm), dr=Point(0mm, -0.4mm), dc=Point(0.4mm, 0mm), nr=2, nc=2))
end

function add_chip_signature!(dev)
    chip_signature = Cell(uniquename("chip_markup"))
    PolyText.polytext!(chip_signature, "ZEP cal SOI\nCQED Lab @ UW", DotMatrix(; pixelsize=25μm, rounding=6μm))
    push!(dev.refs, CellReference(chip_signature, Point(-4.5mm, -5.5mm)))
end

function add_design_name_LL!(dev, design_name)
    annotation_cell = Cell(uniquename("text_WAS01"))
    PolyText.polytext!(annotation_cell, design_name, DotMatrix(; pixelsize=8μm, rounding=1μm, meta = LAYER_RECORD.annotation))
    push!(dev.refs, CellReference(annotation_cell, Point(-2.5mm, -2.5mm), rot=pi/2))
    
end

function add_chip_triangle(dev)
    triangle = Cell(uniquename("triangle"))
    render!(triangle, Polygon(Point(-525µm / 2, 0µm), Point(525µm / 2, 0µm), Point(0µm, 750µm)))
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

function build_transmission_line(; cpw_style=cpw_style)
    (ptL, αL) = ChipTemplates_CQED.launcher_site(16)
    (ptR, αR) = ChipTemplates_CQED.launcher_site(5)

    readout_length = hypot(ptR.x - ptL.x, ptR.y - ptL.y) - (launch_param[:gap0] + launch_param[:flatlen] + launch_param[:taperlen]) * 2 # length of launcher is 650μm

    TL_path = Path(
        ptL + Point(launch_param[:gap0], 0.0μm), # 150μm is the "gap" behind the bonding pad
        α0=αL,
        name="p_ro",
        metadata=LAYER_RECORD.metal_negative
    )
    launch!(TL_path; launch_param...)
    straight!(TL_path, readout_length / 2, cpw_style)
    straight!(TL_path, readout_length / 2, cpw_style)
    launch!(TL_path; launch_param...)
    return TL_path
end

function SimpleDolanJunction(; w_jj=0.3μm, h_jj=0.14μm, h_ground_island=20μm, h_excess=1μm, w_pad_bot=2μm, w_pad_top=2μm, L_taper=0.5μm, L_finger=1.36μm, w_bot_lead_taper=2μm, w_bot_pad=10μm, h_bot_pad=6.55μm)
    jj = Cell(uniquename("jj"), nm)
    # simulation geometry
    jj_rect = centered(Rectangle(w_jj, h_jj))
    top_lead = Align.above(Rectangle(w_pad_top, (h_ground_island - h_jj) / 2 - h_excess), jj_rect; centered=true)
    top_lead_taper = Align.above(Polygon(
            Point(-w_bot_lead_taper - w_pad_bot / 2, 0μm),
            Point(-w_pad_bot / 2, -w_bot_lead_taper),
            Point(w_pad_bot / 2, -w_bot_lead_taper),
            Point(w_pad_bot / 2 + w_bot_lead_taper, 0μm)
        ), top_lead; centered=true)
    top_pad = Align.above(Rectangle(w_bot_pad, h_bot_pad),
        top_lead_taper; centered=true)

    jj_finger = Align.below(Rectangle(w_jj, L_finger), jj_rect; centered=true)
    # taper
    jj_taper = Align.below(Polygon(
            Point(-w_pad_bot / 2, -L_taper),
            Point(-w_jj / 2, 0μm),
            Point(w_jj / 2, 0μm),
            Point(w_pad_bot / 2, -L_taper)
        ), jj_finger; centered=true
    )
    # bottom lead
    bottom_lead = Align.below(Rectangle(w_pad_bot, (h_ground_island - h_jj) / 2 - h_excess - L_taper - L_finger),
        jj_taper; centered=true)
    bottom_lead_taper = Align.below(Polygon(
            Point(-w_bot_lead_taper - w_pad_bot / 2, 0μm),
            Point(-w_pad_bot / 2, w_bot_lead_taper),
            Point(w_pad_bot / 2, w_bot_lead_taper),
            Point(w_pad_bot / 2 + w_bot_lead_taper, 0μm)
        ), bottom_lead; centered=true)
    bottom_pad = Align.below(Rectangle(w_bot_pad, h_bot_pad),
        bottom_lead_taper; centered=true)

    render!(jj, top_lead, LAYER_RECORD.junction_pattern)
    render!(jj, jj_finger, LAYER_RECORD.junction_pattern)
    render!(jj, top_lead_taper, LAYER_RECORD.junction_pattern)
    render!(jj, top_pad, LAYER_RECORD.junction_pattern)
    render!(jj, jj_taper, LAYER_RECORD.junction_pattern)
    render!(jj, bottom_lead, LAYER_RECORD.junction_pattern)
    render!(jj, bottom_lead_taper, LAYER_RECORD.junction_pattern)
    render!(jj, bottom_pad, LAYER_RECORD.junction_pattern)
    render!(jj, union2d(jj_rect, jj_finger), LAYER_RECORD.SE1_device)
    render!(jj, jj_taper, LAYER_RECORD.SE1_device)


    # ground cutout
    a1 = Align.below(Rectangle(2μm, 2μm), bottom_lead; centered=true) - Point(0μm, h_excess - etch_bias_LL)
    a2 = Align.below(Rectangle(6μm, 2μm), a1; centered=true)

    a3 = Align.above(Rectangle(2μm, 2μm), top_lead; centered=true) + Point(0μm, h_excess - etch_bias_LL)
    a4 = Align.above(Rectangle(6μm, 2μm), a3; centered=true)

    render!(jj, union2d(a1, a2), LAYER_RECORD.metal_negative)
    render!(jj, union2d(a3, a4), LAYER_RECORD.metal_negative)

    return jj
end

function make_SQUID(; w_jj1=0.1μm, h_jj1=0.14μm, w_jj2=0.12μm, h_jj2=0.14μm, h_ground_island=20μm, h_excess=3μm, w_pad_bot=2μm, w_pad_top=2μm, L_taper=0.5μm, L_finger=1.36μm, w_squid=10μm)
    asquid = Cell(uniquename("asquid"), nm)
    # simulation geometry
    jj1 = SimpleDolanJunction(; w_jj=w_jj1, h_jj=h_jj1, h_ground_island=h_ground_island, h_excess=h_excess, w_pad_bot=w_pad_bot, w_pad_top=w_pad_top, L_taper=L_taper, L_finger=L_finger)
    jj2 = SimpleDolanJunction(; w_jj=w_jj2, h_jj=h_jj2, h_ground_island=h_ground_island, h_excess=h_excess, w_pad_bot=w_pad_bot, w_pad_top=w_pad_top, L_taper=L_taper, L_finger=L_finger)

    push!(asquid.refs, CellReference(jj1, Point(-w_squid / 2, zero(w_squid))))
    push!(asquid.refs, CellReference(jj2, Point(w_squid / 2, zero(w_squid))))

    return asquid
end

function claw_cpl(; w_shield=2μm, w_claw=35μm, l_claw=160μm, claw_gap=cpw_style.gap + 2 * etch_bias_LL, w_grasp=90μm, arm_trace=cpw_style.trace - 2 * etch_bias_LL)
    claw_hole1 = centered(Rectangle(arm_trace, claw_gap))
    claw_hole2 =
        Rectangle(w_grasp + 2 * w_shield + 4 * claw_gap + 2 * w_claw - 2 * etch_bias_LL, w_claw + 2 * claw_gap - 2 * etch_bias_LL)
    claw_hole2 = flushtop(claw_hole2, claw_hole1, centered=true)

    claw_hole3 = Rectangle(w_claw + 2 * claw_gap - 2 * etch_bias_LL, w_shield + l_claw + claw_gap + etch_bias_LL)
    claw_hole3 = flushleft(below(claw_hole3, claw_hole2), claw_hole2)

    claw_hole4 = flushright(claw_hole3, claw_hole2)

    claw1 = Rectangle(arm_trace + 2 * etch_bias_LL, claw_gap - 2 * etch_bias_LL)
    claw1 = flushtop(claw1, claw_hole1, centered=true)

    claw2 = Rectangle(w_grasp + 2 * w_shield + 2 * claw_gap + 2 * w_claw + 2 * etch_bias_LL, w_claw + 2 * etch_bias_LL)
    claw2 = below(claw2, claw1, centered=true)

    claw3 = Rectangle(w_claw + 2 * etch_bias_LL, claw_gap + w_shield + l_claw + etch_bias_LL)
    claw3 = flushleft(below(claw3, claw2), claw2)

    claw4 = flushright(claw3, claw2)

    claw = difference2d(
        [claw_hole1, claw_hole2, claw_hole3, claw_hole4],
        [claw1, claw2, claw3, claw4]
    )

    csr_claw_cpl = CoordinateSystem("claw_cpl", nm)

    place!(csr_claw_cpl, claw + Point(0μm, w_claw + claw_gap * 1.5 + w_shield * 1), LAYER_RECORD.metal_negative) # move the
    return Cell(csr_claw_cpl)
end

function qubit_cap_cross(; cap_width=30μm, cap_length=410μm, cap_gap=30μm, junction_gap=20.0μm, island_rounding=0μm)
    csr_qubit_cap = CoordinateSystem(uniquename("qubit_cap"), nm)

    # Capacitor metal
    qubitIsland = union2d(
        Rectangle(Point(-cap_width / 2 - etch_bias_LL, 0µm - etch_bias_LL), Point(cap_width / 2 + etch_bias_LL, cap_length + etch_bias_LL)) + Point(0µm, junction_gap / 2),
        Rectangle(Point(-cap_length / 2 - etch_bias_LL, -cap_width / 2 - etch_bias_LL), Point(cap_length / 2 + etch_bias_LL, cap_width / 2 + etch_bias_LL)) + Point(0µm, junction_gap / 2 + cap_length / 2)
    )

    # Capacitor ground
    gapFill = union2d(
        Rectangle(Point(-cap_width / 2 - cap_gap + etch_bias_LL, cap_length + junction_gap / 2 + cap_gap - etch_bias_LL),
            Point(cap_width / 2 + cap_gap - etch_bias_LL, -junction_gap / 2 + etch_bias_LL)),
        Rectangle(Point(-cap_length / 2 - cap_gap + etch_bias_LL, -cap_width / 2 - cap_gap + etch_bias_LL), Point(cap_length / 2 + cap_gap - etch_bias_LL, cap_width / 2 + cap_gap - etch_bias_LL)) + Point(0µm, junction_gap / 2 + cap_length / 2)
    )

    diff = Rounded(island_rounding)(difference2d(gapFill, qubitIsland))

    #render!(qubit_cap, diff, LAYER_RECORD.metal_negative)
    #push!(qubit_cap.refs, CellReference(qubit_island, Point(0μm, 0μm)))

    place!(csr_qubit_cap, diff, LAYER_RECORD.metal_negative)

    claw = claw_cpl()

    qubit_cap = Cell(csr_qubit_cap, nm)

    push!(qubit_cap.refs, CellReference(claw, Point(0μm, cap_length + cap_gap + junction_gap / 2 - etch_bias_LL)))

    return qubit_cap
end

function make_qubit_cell(;)
    Qubit_cell = Cell(uniquename("Qubit"), nm)
    qubit_island = qubit_cap_cross()
    jj = make_SQUID()

    # the JJs/SQUID
    push!(Qubit_cell.refs, CellReference(qubit_island, Point(0μm, 0μm)))
    push!(Qubit_cell.refs, CellReference(jj, Point(0μm, 0μm), rot=0))

    return Qubit_cell
end

function create_resonator(style, p0; total_length=4860μm, coupling_length=400μm, coupling_gap=5μm, bend_radius=50μm, n_meander_turns=5, total_height=1450μm, hanger_length=500μm, w_shield=2μm)
    path = Path(
        p0 + Point(-coupling_length / 2, -coupling_gap - style.gap * 2 - style.trace - 2 * etch_bias_LL),
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
            straight!(path, 200μm, Paths.TaperCPW(style.trace, style.gap, 5.5μm + 2 * etch_bias_LL, 2.9μm - 2 * etch_bias_LL))
            straight!(path, 100μm, Paths.CPW(5.5μm + 2 * etch_bias_LL, 2.9μm - 2 * etch_bias_LL))
            straight!(path, 50μm)
            flux_bias_cell = Cell(uniquename("flux_bias"), nm)
            flux_bias!(flux_bias_cell, "r", 6.35μm, 2.9μm, 4.35μm, 5.5μm + 2 * etch_bias_LL, 2.9μm - 2 * etch_bias_LL) # flux_over, flux_under, flux_cut, z_trace, z_gap,
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

function generate_XYline_instructions!(path, style, instructions)
    # 'straight' instructions are parameterized by the length of straight cpw to
    #     append
    # 'turn' instructions are parameterized by the angle to turn and the radius of
    #     the turn
    for instruction in instructions
        if instruction[1] == "straight"
            straight!(path, instruction[2], style)
        elseif instruction[1] == "turn"
            turn!(path, instruction[2], instruction[3])
        elseif instruction[1] == "endXY"
            straight!(path, 100μm, Paths.TaperCPW(style.trace, style.gap, 5.5μm + 2 * etch_bias_LL, 2μm))
            straight!(path, 100μm, Paths.CPW(5.5μm + 2 * etch_bias_LL, 2μm))
            straight!(path, 2μm, Paths.Trace(5.5μm + 2 * etch_bias_LL + 4μm))
        end
    end
end

_is_termination(sty) = occursin("termination", lowercase(string(typeof(sty))))

_seglen(seg) =
    pathlength(seg)

"""
    center_trace_path(p; skip_terminations=true, skip_zero_trace=true)

Convert CPW path → center trace only.

Rules:
- termination → skip
- trace == 0 → skip
- SimpleCPW  → Trace(width)
- TaperCPW   → TaperTrace(w0,w1)
- others     → unchanged
"""
function center_trace_path(p::Paths.Path;
    skip_terminations=true,
    skip_zero_trace=true,
    name=nothing,
    metadata=nothing
)

    out = Paths.Path(
        p.p0;
        α0=p.α0,
        name=isnothing(name) ? "$(p.name)_trace" : name,
        metadata=isnothing(metadata) ? p.metadata : metadata,
    )

    for node in p.nodes
        sty = Paths.style(node)

        # -------------------------
        # 1) skip termination
        # -------------------------
        if skip_terminations && _is_termination(sty)
            continue
        end

        segs = Paths.segment(node)
        seglist = segs isa AbstractVector || segs isa Tuple ? segs : (segs,)

        for seg in seglist
            Lseg = _seglen(seg)

            newsty = nothing

            # =========================
            # SimpleCPW
            # =========================
            if sty isa Paths.SimpleCPW
                w = Paths.trace(sty)

                if skip_zero_trace && iszero(w)
                    continue
                end

                newsty = Paths.Trace(w)

                # =========================
                # TaperCPW
                # =========================
            elseif sty isa Paths.TaperCPW
                w0 = Paths.trace(sty, zero(Lseg))
                w1 = Paths.trace(sty, Lseg)

                if skip_zero_trace && iszero(w0) && iszero(w1)
                    continue
                end

                tsty = Paths.TaperTrace(w0, w1)
                newsty = Paths._withlength!(tsty, Lseg)

                # =========================
                # others → leave unchanged
                # =========================
            else
                try
                    w0 = Paths.trace(sty, zero(Lseg))
                    w1 = Paths.trace(sty, Lseg)

                    if isapprox(w0, w1)
                        newsty = Paths.Trace(w0)
                    else
                        tsty = Paths.TaperTrace(w0, w1)
                        newsty = Paths._withlength!(tsty, Lseg)
                    end

                catch
                    # no trace → leave alone
                    newsty = sty
                end
            end

            push!(out.nodes, Paths.Node(seg, newsty))
        end
    end

    return out
end

function main()
    # Chip
    design_name = "WAS01"
    device = Cell(design_name, nm)

    ChipTemplates_CQED.build_device!(device;
        chip_width=chip_width,
        chip_height=chip_height,
        deadzone_width=deadzone_width,
        deadzone_height=deadzone_height
    )

    TL_path = build_transmission_line(cpw_style=cpw_style)

    (ptL, αL) = ChipTemplates_CQED.launcher_site(16)
    RO1_path = create_resonator(cpw_style, ptL + Point(1500μm, 0μm))

    # Z line
    (ptZ1, αZ1) = ChipTemplates_CQED.launcher_site(11)
    Z1_path = Path(ptZ1 + Point(0µm, launch_param[:gap0]), α0=αZ1)
    launch!(Z1_path; launch_param...)
    Z1_instructions = [
        ["straight", 370.9μm - 58.069μm],
        ["turn", pi / 6, 500μm],
        ["straight", 282μm],
        ["turn", -pi / 6, 500μm],
        ["straight", 50μm],
        ["endZ"]
    ]
    generate_Zline_instructions!(Z1_path, cpw_style, Z1_instructions)

    # XY line
    (ptXY1, αXY1) = ChipTemplates_CQED.launcher_site(14)
    XY1_path = Path(ptXY1 + Point(launch_param[:gap0], 0µm), α0=αXY1)
    launch!(XY1_path; launch_param...)
    XY1_instructions = [
        ["straight", (270 - 1.264)μm],
        ["turn", pi / 4, 200μm],
        ["straight", 200μm],
        ["turn", -pi / 4, 200μm],
        ["straight", 65μm],
        ["endXY"]
    ]
    generate_XYline_instructions!(XY1_path, cpw_style, XY1_instructions)

    # XY line
    (ptXY2, αXY2) = ChipTemplates_CQED.launcher_site(13)
    XY2_path = Path(ptXY2 + Point(launch_param[:gap0], 0µm), α0=αXY2)
    launch!(XY2_path; launch_param...)
    XY2_instructions = [
        ["straight", (210 - 7.13)μm],
        ["turn", pi / 2.5, 100μm],
        ["straight", 1100μm],
        ["turn", -pi / 2.5, 100μm],
        ["straight", 25μm],
        ["endXY"]
    ]
    generate_XYline_instructions!(XY2_path, cpw_style, XY2_instructions)

    # XY line
    (ptXY3, αXY3) = ChipTemplates_CQED.launcher_site(10)
    XY3_path = Path(ptXY3 + Point(0µm, launch_param[:gap0]), α0=αXY3)
    launch!(XY3_path; launch_param...)
    XY3_instructions = [
        ["straight", (210 - 7.13 + 1.955)μm],
        ["turn", pi / 5, 100μm],
        ["straight", 1390μm],
        ["turn", pi * (0.5 - 1 / 5), 100μm],
        ["straight", 145.978μm],
        ["endXY"]
    ]
    generate_XYline_instructions!(XY3_path, cpw_style, XY3_instructions)

    # XY line
    (ptXY4, αXY4) = ChipTemplates_CQED.launcher_site(9)
    XY4_path = Path(ptXY4 + Point(0µm, launch_param[:gap0]), α0=αXY4)
    launch!(XY4_path; launch_param...)
    XY4_instructions = [
        ["straight", (210 - 3.401)μm],
        ["turn", pi / 3.5, 100μm],
        ["straight", 2000μm],
        ["turn", pi * (0.5 - 1 / 3.5), 100μm],
        ["straight", 449.337μm],
        #["straight", 200μm],
        ["endXY"]
    ]
    generate_XYline_instructions!(XY4_path, cpw_style, XY4_instructions)

    # add the qubit to RO
    qubit = make_qubit_cell()
    p_1 = Paths.p1(RO1_path)
    α_1 = Paths.α1(RO1_path)               # replace with your actual endpoint function
    push!(device.refs, CellReference(qubit, p_1 - Point(0μm, junction_gap / 2 + cap_length + cap_gap + w_shield + w_claw + claw_gap * 2 - etch_bias_LL), rot=0))

    # add a line to RO current antinode, for convenient of Boolean operation
    p_0 = Paths.p0(RO1_path)
    α_0 = Paths.α0(RO1_path)
    render!(device, rotate(centered(Rectangle(0nm, cpw_style.trace + 2 * cpw_style.gap)), π - α_0) + p_0, LAYER_RECORD.metal_positive)

    # add a line to Z control current antinode, for convenient of Boolean operation
    p_1 = Paths.p1(Z1_path)
    α_1 = Paths.α1(Z1_path)
    render!(device, rotate(centered(Rectangle(0nm, cpw_style.trace + 2 * cpw_style.gap)), α_1 + π / 2) + p_1 + Point(5.5μm / 2 + 2.9μm + 2.9μm - etch_bias_LL, 5.5μm / 2 + 2μm - etch_bias_LL), LAYER_RECORD.metal_positive)

    # render all paths
    render!(device, TL_path, LAYER_RECORD.metal_negative)
    render!(device, RO1_path, LAYER_RECORD.metal_negative)
    render!(device, Z1_path, LAYER_RECORD.metal_negative)
    render!(device, XY1_path, LAYER_RECORD.metal_negative)
    render!(device, XY2_path, LAYER_RECORD.metal_negative)
    render!(device, XY3_path, LAYER_RECORD.metal_negative)
    render!(device, XY4_path, LAYER_RECORD.metal_negative)

    # add bonding pad label 5/11
    pad_label = centered(Rectangle(launch_param[:flatlen], launch_param[:trace0]))
    for i in [TL_path, Z1_path, XY1_path, XY2_path, XY3_path, XY4_path]
        p_0 = Paths.p0(i)
        α_0 = Paths.α0(i)
        render!(device, rotate(pad_label + Point(launch_param[:flatlen] / 2 + launch_param[:gap0], 0nm), α_0) + p_0, LAYER_RECORD.launch_pad)
    end
    p_1 = Paths.p1(TL_path)
    α_1 = Paths.α1(TL_path)
    render!(device, rotate(pad_label + Point(launch_param[:flatlen] / 2 + launch_param[:gap0], 0nm), α_1 + π) + p_1, LAYER_RECORD.launch_pad)

    #flatten!(device)
    add_design_name_LL!(device, design_name)

    c_output_gds = Cell("HIERARCHY", nm)
    addref!(c_output_gds, sref(device, rot=-90°)) # correct any rotations

    #place!(cs_device, chip, metadata=LayerVocabulary.METAL_POSITIVE)

    save(joinpath(@__DIR__, "FUN17_CQED.gds"), c_output_gds)
end

# run the code
main()

