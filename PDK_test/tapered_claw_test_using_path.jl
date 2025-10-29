import .ExamplePDK.Transmons: ExampleRectangleTransmon

using DeviceLayout, DeviceLayout.SchematicDrivenLayout, DeviceLayout.PreferredUnits, DeviceLayout.SimpleShapes
using .SchematicDrivenLayout.ExamplePDK, .ExamplePDK.LayerVocabulary

import .ExamplePDK: add_bridges!, filter_params, tap!

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
  - `claw_gap`: Claw capacitor gap
  - `bridge`: `CoordinateSystem` containing a bridge
"""
@compdef struct TaperedClawedMeanderReadout <: Component
    name = "rres"
    style = Paths.CPW(10.0μm, 6.0μm)
    total_length = 5000μm
    coupling_length = 200μm
    coupling_gap = 5μm
    bend_radius = 50μm
    n_meander_turns = 5
    total_height = 1656μm # from top hook to bottom hook
    hanger_length = 500μm
    taper_style = Paths.CPW(1.0μm, 0.5μm)
    taper_length = 5μm
    r_taper = 10μm
    gap_claw = 0.8μm
    α_claw = 20°
    r_claw = 20μm # radius
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
        taper_style,
        taper_length,
        r_taper,
        gap_claw,
        α_claw,
        r_claw,
        bridge
    ) = parameters(rres)
    # Center vertical axis is midpoint of coupling section
    pres = Path(
        Point(-coupling_length / 2, -coupling_gap - style.gap - style.trace / 2),
        α0=0°
    )
    n_bends = 3 + 2 * n_meander_turns # number of 90 degree bends
    arm_length = (
        total_height - hanger_length - n_bends * bend_radius - coupling_gap - style.gap - style.trace / 2 - 2 * style.gap - style.trace
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

    # start the split into two paths
    main_sty = laststyle(pres)
    main_sty isa Paths.CPW || error("Last path style should be CPW for a CPW tap")
    main_trace = Paths.trace(main_sty, pathlength(pres[end]))
    main_gap = Paths.gap(main_sty, pathlength(pres[end]))
    location = 1

    ### Claw
    tap1 = Path(
        p1(pres) + main_trace / 2 * Point(cos(α1(pres)), sin(α1(pres)))
        -
        sign(location) * main_trace / 2 * Point(-sin(α1(pres)), cos(α1(pres))), # shift sideways by main_trace/2, so tap1 starts from the gap of the main trace
        α0=α1(pres) - sign(location) * 90°,
        metadata=pres.metadata,
        name=uniquename("tap")
    )

    tap2 = Path(
        p1(pres) + main_trace / 2 * Point(cos(α1(pres)), sin(α1(pres)))
        +
        sign(location) * main_trace / 2 * Point(-sin(α1(pres)), cos(α1(pres))), # shift sideways by main_trace/2, so tap1 starts from the gap of the main trace
        α0=α1(pres) + sign(location) * 90°,
        metadata=pres.metadata,
        name=uniquename("tap")
    )

    # terminate the main path
    norender = Paths.SimpleNoRender(main_trace, virtual=true)
    straight!(pres, main_trace, norender)
    straight!(pres, 0μm, Paths.CPW(main_trace, 0μm))
    terminate!(pres; gap=main_gap)

    # tap1
    straight!(tap1, taper_style.trace / 2 + gap_claw / 2, main_sty)
    turn!(tap1, 90° + α_claw, r_claw)
    l_taper = (r_claw * cos(α_claw) + main_trace / 2 - r_taper * (1 - cos(α_claw))) / sin(α_claw)
    straight!(tap1, l_taper, Paths.Taper())
    turn!(tap1, -α_claw, r_taper, taper_style)
    straight!(tap1, taper_length)
    terminate!(tap1; gap=taper_style.gap)

    # tap2
    straight!(tap2, taper_style.trace / 2 + gap_claw / 2, main_sty)
    turn!(tap2, -90° - α_claw, r_claw)
    straight!(tap2, l_taper, Paths.Taper())
    turn!(tap2, α_claw, r_taper, taper_style)
    straight!(tap2, taper_length)
    terminate!(tap2; gap=taper_style.gap)

    render!.(cs, [pres, tap1, tap2], METAL_NEGATIVE)

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
    qubit_hook = PointHook(Point(zero(rres.style.trace), -rres.total_height), 90°)
    feedline_hook = PointHook(zero(Point{typeof(rres.style.trace)}), -90°)
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