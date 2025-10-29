import DeviceLayout: flushtop, flushleft, flushright, below, above, center

import .ExamplePDK.Transmons: ExampleRectangleTransmon

using DeviceLayout, DeviceLayout.SchematicDrivenLayout, DeviceLayout.PreferredUnits, DeviceLayout.SimpleShapes
using .SchematicDrivenLayout.ExamplePDK, .ExamplePDK.LayerVocabulary

import .ExamplePDK: add_bridges!, filter_params, tap!
import .ExamplePDK.ClawCapacitors: ExampleShuntClawCapacitor

export TaperedClawedMeanderReadout


"""
    struct TaperedClawedMeanderReadout <: Component

Readout resonator consisting of a meander with short and claw-capacitor terminations.

This component is intended for use in demonstrations with `ExampleRectangleTransmon`.

# Parameters

  - `name`: Name of component
  - `style`: Resonator CPW style
  - `total_length`: Total length of resonator
  - `coupling_length`: Length of coupling section
  - `coupling_gap`: Width of ground plane between coupling section and coupled line
  - `bend_radius`: Meander bend radius
  - `n_meander_turns`: Number of meander turns
  - `total_height`: Total height from top hook to bottom hook
  - `hanger_length`: Length of hanger section between coupling section and meander
  - `w_shield`: Width of claw capacitor ground plane shield
  - `w_claw`: Claw trace width
  - `l_claw`: Claw finger length
  - `claw_gap`: Claw capacitor gap
  - `w_grasp`: Width between inner edges of ground plane shield
  - `bridge`: `CoordinateSystem` containing a bridge
"""
@compdef struct TaperedClawedMeanderReadout <: Component
    name = "rres"
    style = DeviceLayout.Paths.SimpleCPW(10.0μm, 6.0μm)
    total_length = 5000μm
    coupling_length = 200μm
    coupling_gap = 5μm
    bend_radius = 50μm
    n_meander_turns = 5
    total_height = 1656μm # from top hook to bottom hook
    hanger_length = 500μm
    w_shield = 2μm
    w_claw = 32μm
    l_claw = 160μm
    claw_gap = 6μm
    w_grasp = 84μm
    bridge = CoordinateSystem("rresbridge", nm)
end

function SchematicDrivenLayout._geometry!(
    cs::CoordinateSystem,
    rres::TaperedClawedMeanderReadout
)
    (;
        style,
        total_length,
        coupling_length,
        coupling_gap,
        bend_radius,
        n_meander_turns,
        total_height,
        hanger_length,
        w_shield,
        w_claw,
        l_claw,
        claw_gap,
        w_grasp,
        bridge
    ) = parameters(rres)
    # Center vertical axis is midpoint of coupling section
    pres = Path(
        Point(-coupling_length / 2, -coupling_gap - style.gap - style.trace / 2),
        α0=0°
    )
    n_bends = 3 + 2 * n_meander_turns # number of 90 degree bends
    arm_length = (
        total_height - hanger_length - n_bends * bend_radius - coupling_gap - style.gap - style.trace / 2 - w_shield - 2 * claw_gap - w_claw
    )

    # Length of straight sections in meander
    straight_length =
        (
            total_length - 3 * coupling_length / 2 - n_bends * pi * bend_radius / 2 -
            arm_length - hanger_length
        ) / n_meander_turns

    ### CPW path
    straight!(pres, coupling_length, style)
    turn!(pres, -90°, bend_radius)
    straight!(pres, hanger_length)
    attach!(pres, CoordinateSystemReference(bridge), hanger_length / 2)
    turn!(pres, -90°, bend_radius)
    # Center of the straight section of meander lines up with coupling midpoint (and claw)
    straight!(pres, straight_length / 2 + coupling_length / 2)
    turn!(pres, 180°, bend_radius)

    # Start the meander with a full straight section
    meander_length =
        (n_meander_turns - 1) * (straight_length + pi * bend_radius) + straight_length / 2 -
        bend_radius
    meander!(pres, meander_length, straight_length, bend_radius, -180°)
    turn!(pres, -90°, bend_radius)
    straight!(pres, arm_length)
    attach!(pres, CoordinateSystemReference(bridge), arm_length / 2)

    ## temporary, params for the taper
    taper_trace = 1μm
    taper_gap = 0.5μm
    taper_length = 5μm
    r_taper = 10μm

    gap_claw = 1μm

    #w_claw = 100μm # width
    r_claw = 20μm # radius
    #l_claw = 50μm # length
    α_claw = 30°

    taper_style = Paths.CPW(taper_trace, taper_gap)

    main_sty = laststyle(pres)
    main_sty isa Paths.CPW || error("Last path style should be CPW for a CPW tap")
    main_trace = Paths.trace(main_sty, pathlength(pres[end]))
    main_gap = Paths.gap(main_sty, pathlength(pres[end]))

    ### Claw
    arm_trace = style.trace
    pt0 = p1(pres.nodes[end].seg)

    claw_hole1 = Rectangle(arm_trace, claw_gap) + pt0 + Point(-arm_trace / 2, -claw_gap)
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

    tapered_claw1_1 = Rectangle(main_trace + main_gap * 2 + taper_trace + taper_gap, main_gap * 2 + w_claw) + pt0 - Point((main_trace + main_gap * 2 + taper_trace + taper_gap) / 2, main_gap * 2 + w_claw)
    poly = _half_pie(r_claw, α_claw) - pt0
    place!(cs, rotate(poly, π), METAL_POSITIVE)
    #tapered_claw1_2 = SimpleShapes.radial_cut(r_claw, 60°, 0μm)
    #tapered_claw = tapered_claw1_2 + pt0
    render!.(cs, [pres, claw], METAL_NEGATIVE)
    #render!(cs, tapered_claw, METAL_POSITIVE)

    return cs
end

"""
    hooks(rres::ExampleClawedMeanderReadout)

`Hook`s for attaching a readout resonator claw to a qubit and coupling section to a feedline.

  - `qubit`: The "palm" of the claw on the outside edge of the "shield". Matches
    `(eq::ExampleRectangleTransmon) => :rres`.
  - `feedline`: A distance `coupling_gap` from the edge of the ground plane, vertically aligned
    with the claw.
"""
function SchematicDrivenLayout.hooks(rres::TaperedClawedMeanderReadout)
    qubit_hook = PointHook(Point(zero(rres.w_claw), -rres.total_height), 90°)
    feedline_hook = PointHook(zero(Point{typeof(rres.w_claw)}), -90°)
    return (qubit=qubit_hook, feedline=feedline_hook)
end

SchematicDrivenLayout.matching_hooks(
    ::ExampleRectangleTransmon,
    ::TaperedClawedMeanderReadout
) = (:readout, :qubit)
SchematicDrivenLayout.matching_hooks(
    ::TaperedClawedMeanderReadout,
    ::ExampleRectangleTransmon
) = (:qubit, :readout)

function _half_pie(r, α; h=0μm, narc::Int=197)
    p = Path(Point(h * tan(α / 2), -h), α0=α - π / 2)
    straight!(p, r - h * sec(α / 2), Paths.Trace(r)) # Trace could be anything
    turn!(p, -π / 2, zero(h))
    turn!(p, -α, r)
    turn!(p, -π / 2, zero(h))
    straight!(p, r - h * sec(α / 2))

    seg = segment(p[3])
    pts = map(seg, range(pathlength(seg), stop=zero(h), length=narc))

    push!(pts, Paths.p1(p))
    h != zero(h) && push!(pts, Paths.p0(p))
    poly = Polygon(pts) + Point(zero(h), h) # + Point(0.0, (r-h)/2)
    return poly
end