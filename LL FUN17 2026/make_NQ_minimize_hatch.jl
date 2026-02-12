function NQ_JJ_left(c, w1, l1, w2, l2, w3, l3, w4, l4, xshift=0um, yshift=0um, bandaid_finger_h=bandaid_finger_h, bandaid_finger_w=bandaid_finger_w; jjlayer=JJ_LAYER, undercut_layer=UC_LAYER, gnd_cutout_layer=GND_CUTOUT_LAYER, bandaid_layer=BANDAID_LAYER)
    # start drawing JJ
    # JJ
    render!(c, Rectangle(Point(-w1 / 2 + xshift, -l1 - l2 / 2), Point(w1 / 2 + xshift, -l2 / 2 - ruc / 2)), GDSMeta(jjlayer))
    render!(c, Rectangle(Point(-w2 / 2 - uuc / 2, -l2 / 2 - ruc / 2), Point(w2 / 2 - uuc / 2, l2 / 2 - ruc / 2)),
        Rectangles.Undercut(0.0um, uuc, ruc, 0.0um, GDSMeta(jjlayer), GDSMeta(undercut_layer)))
    render!(c, Rectangle(Point(-w3 - w2 / 2, -l3 / 2 + yshift), Point(-w2 / 2 - ruc / 2, l3 / 2 + yshift)),
        GDSMeta(jjlayer))
    render!(c, Rectangle(Point(-w4 - w3 - w2 / 2, -l3 / 2 + yshift), Point(-w3 - w2 / 2, -l3 / 2 + l4)),
        Rectangles.Undercut(0.0um, uuc, ruc, 0.0um, GDSMeta(jjlayer), GDSMeta(undercut_layer)))

    # hatch
    for i in range(0, 5, step=1) #lays out bandaid fingers and their correspondonding undercut
        render!(c, Rectangle(bandaid_finger_h, bandaid_finger_w) + Point(-w4 - w3 - w2 / 2 - bandaid_finger_h, -l3 / 2 + l4 - bandaid_finger_w - i * 0.8um), GDSMeta(jjlayer))
    end

    # GND cutout1
    render!(c, Rectangle(Point(-w4 - w3 - w2 / 2, -l3 / 2 + yshift), Point(-w3 - w2 / 2 + ruc, -l3 / 2 + l4 + uuc)), GDSMeta(GND_CUTOUT_LAYER))
    bigger_bandaid = Rectangle(Point(ruc + gnd_cutout_margin, -l3 / 2 + l4 - qubit_cap_bottom_gap / 2 + 1um), Point(-w4 - bandaid_finger_h - gnd_cutout_margin, -l3 / 2 + l4 + uuc))
    render!(c, bigger_bandaid + Point(-w3 - w2 / 2, 0um), GDSMeta(GND_CUTOUT_LAYER))
    # GND cutout2
    smaller_bandaid = Rectangle(Point(-w1 / 2 + xshift - gnd_cutout_margin, -l1 - l2 / 2), Point(w1 / 2 + xshift + gnd_cutout_margin, -qubit_cap_bottom_gap / 2))
    render!(c, smaller_bandaid + Point(xshift, 0um), GDSMeta(GND_CUTOUT_LAYER))
    # make the JJ leads away from phononic shield slightly wider
    JJ_lead_widen = Rectangle(Point(xshift - w1_widen / 2, -l1 - l2 / 2), Point(xshift + w1_widen / 2, -qubit_cap_bottom_gap / 2))
    render!(c, JJ_lead_widen + Point(xshift, 0um), GDSMeta(JJ_LAYER))

    # bandaid1
    bigger_bandaid = Rectangle(Point(ruc + bandaid_margin, -l3 / 2 + l4 - qubit_cap_bottom_gap / 2 + 1um), Point(-w4 - bandaid_finger_h - bandaid_margin, -l3 / 2 + l4 + uuc))
    render!(c, Rounded(0.2um)(bigger_bandaid) + Point(-w3 - w2 / 2, 0um), GDSMeta(BANDAID_LAYER))
    #bandaid2
    smaller_bandaid = Rectangle(Point(-w1 / 2 + xshift - bandaid_margin, -l1 - l2 / 2), Point(w1 / 2 + xshift + bandaid_margin, -qubit_cap_bottom_gap / 2))
    render!(c, Rounded(0.2um)(smaller_bandaid) + Point(xshift, 0um), GDSMeta(BANDAID_LAYER))

    # union of undercuts
    inds = findall(x -> layer(x) == layer(GDSMeta(undercut_layer)), c.elements)
    res = clip(ClipTypeUnion, polygon.(view(c.elements, inds)), Polygon{typeof(1.0um)}[],
        pfs=Clipper.PolyFillTypePositive)
    deleteat!(c.elements, inds)
    append!(c.elements, CellPolygon.(res, [GDSMeta(undercut_layer)]))

    # no overlaps of UC_LAYER and LAYER
    inds = findall(x -> layer(x) == layer(GDSMeta(undercut_layer)), c.elements)
    inds2 = findall(x -> layer(x) == layer(GDSMeta(jjlayer)), c.elements)
    res = clip(ClipTypeDifference, polygon.(view(c.elements, inds)),
        polygon.(view(c.elements, inds2)))
    deleteat!(c.elements, inds)
    append!(c.elements, CellPolygon.(res, [GDSMeta(undercut_layer)]))

    flatten!(c)
end

function make_SQUID(w1, l1, w2, l2, w3, l3, w4, l4, pad_h, pad_w, bandaid_finger_h, bandaid_finger_w, squid_separation_bottom, xshift, yshift; jjlayer=JJ_LAYER, undercut_layer=UC_LAYER, gnd_cutout_layer=GND_CUTOUT_LAYER, bandaid_layer=BANDAID_LAYER)
    jj_height = l1 + l2 / 2 - l3 / 2 + l4
    asquid = Cell(uniquename("asymmetric squid"), nm)
    leftjjcell = Cell(uniquename("leftjj"), nm)
    NQ_JJ_left(leftjjcell, w1, l1, w2, l2, w3, l3, w4, l4, xshift, yshift, jjlayer=jjlayer, undercut_layer=undercut_layer, gnd_cutout_layer=GND_CUTOUT_LAYER, bandaid_layer=BANDAID_LAYER)
    push!(asquid.refs, CellReference(leftjjcell, Point(-(squid_separation_bottom) / 2, 0um)))
    push!(asquid.refs, CellReference(leftjjcell, Point((squid_separation_bottom) / 2, 0um)))

    flatten(asquid)
    return asquid
end

function claw_cpl(c, trace, gap, claw_length, ground_gap, qubit_width, qubit_gap)
    claw_width = trace
    claw_gap = gap
    totalWidthGap = claw_width * 2 + claw_gap * 4 + ground_gap * 2 + qubit_width + qubit_gap * 2
    totalWidth = totalWidthGap - 2 * claw_gap

    ground = Rectangle(Point(-claw_gap, -totalWidthGap / 2), Point(claw_gap + claw_length, totalWidthGap / 2))
    top = Rectangle(Point(0um, -totalWidth / 2), Point(claw_width, totalWidth / 2))
    left = Rectangle(Point(0um, -totalWidth / 2), Point(claw_length, -totalWidth / 2 + claw_width))
    right = Rectangle(Point(0um, totalWidth / 2 - claw_width), Point(claw_length, totalWidth / 2))
    middle = Rectangle(Point(claw_width + claw_gap, -totalWidth / 2 + claw_width + claw_gap), Point(claw_gap + claw_length, totalWidth / 2 - claw_width - claw_gap))
    readoutres = Rectangle(Point(-claw_gap, -trace / 2 - gap), Point(0um, trace / 2 + gap))

    gr = clip(ClipTypeDifference, ground, readoutres)[1]
    #gr = ground
    g = clip(ClipTypeDifference, gr, middle)[1]
    tl = clip(ClipTypeUnion, top, left)[1]
    metal = clip(ClipTypeUnion, tl, right)[1]
    for cut in clip(ClipTypeDifference, g, metal)
        render!(c, cut, GDSMeta(GROUND_PLANE))
    end
end

function qubit_cap(c, qubit_length, qubit_width, qubit_gap, qubit_cap_bottom_gap)

    # Capacitor metal
    qubitCap = Rectangle(Point(-qubit_width / 2, 0um), Point(qubit_width / 2, qubit_length))

    # Capacitor ground
    gapFill = Rectangle(Point(-qubit_width / 2 - qubit_gap, -qubit_cap_bottom_gap),
        Point(qubit_width / 2 + qubit_gap, qubit_gap + qubit_length))

    cuts = clip(ClipTypeDifference, gapFill, qubitCap)[1]

    render!(c, cuts, GDSMeta(GROUND_PLANE))
end

function create_resonator(path, L2, hole_path, dir; ResStraight=ResStraight)
    # path for the resonator
    # dir = 0: for RO on the left
    # dir = 1: change direction of all turns, for RO on the right
    straight!(path, Res_coupling, cpw_style)
    turn!(path, (-1)^(dir + 1) * pi / 2, turnRadRes, cpw_style)
    straight!(path, 300um, cpw_style)
    turn!(path, (-1)^(dir + 1) * pi / 2, turnRadRes, cpw_style)

    for hlp in 1:5
        straight!(path, ResStraight, cpw_style)
        turn!(path, (-1)^(hlp + 1 + dir) * pi, turnRadRes, cpw_style)
    end

    straight!(path, 317.5um + L2, cpw_style)
    #turn!(path, -pi/2, turnRadRes, cpw_style)
    #straight!(path, L2, cpw_style)

    # path for the HF holes
    straight!(hole_path, Res_coupling + turnRadRes, Paths.Trace(0.0um))
    turn!(hole_path, (-1)^(dir + 1) * pi / 2, 1.0nm)
    straight!(hole_path, 300um + turnRadRes * 2, Paths.Trace(0.0um))
    turn!(hole_path, (-1)^(dir + 1) * pi / 2, 1.0nm)

    for hlp in 1:5
        straight!(hole_path, ResStraight + turnRadRes * 2)
        turn!(hole_path, (-1)^(hlp + 1 + dir) * pi / 2, 1.0nm)
        straight!(hole_path, turnRadRes * 2)
        turn!(hole_path, (-1)^(hlp + 1 + dir) * pi / 2, 1.0nm)
    end

    straight!(hole_path, 200um + turnRadRes + 117.5um + L2)
end

function attach_hole_res(res_path, dir)
    attach!(res_path, CPW_hole_ref, (-hole_extent+1um):(4um):(pathlength(res_path[1])+soi_trace/2+soi_gap+hole_extent), i=1)
    if dir == 1
        for hlp in 3:2:5
            if mod(hlp, 4) == 1
                attach!(res_path, CPW_hole_ref, (2.0um):(4um):(pathlength(res_path[hlp])+soi_trace/2+soi_gap+hole_extent), i=hlp)
            else
                attach!(res_path, CPW_hole_ref_offset1, (0.0um):(4um):(pathlength(res_path[hlp])+soi_trace/2+soi_gap+hole_extent), i=hlp)
            end
        end
        for hlp in 7:2:(length(res_path)-1)
            if mod(hlp, 8) == 7
                attach!(res_path, CPW_hole_ref_offset3, (0.0um):(4um):(pathlength(res_path[hlp])+soi_trace/2+soi_gap+hole_extent), i=hlp)
            elseif mod(hlp, 8) == 1
                attach!(res_path, CPW_hole_ref, (0.0um):(4um):(pathlength(res_path[hlp])+soi_trace/2+soi_gap+hole_extent), i=hlp)
            elseif mod(hlp, 8) == 3
                attach!(res_path, CPW_hole_ref_offset1, (0.0um):(4um):(pathlength(res_path[hlp])+soi_trace/2+soi_gap+hole_extent), i=hlp)
            elseif mod(hlp, 8) == 5
                attach!(res_path, CPW_hole_ref, (2.0um):(4um):(pathlength(res_path[hlp])+soi_trace/2+soi_gap+hole_extent), i=hlp)
            end
        end
        hlp = length(res_path)
        if mod(hlp, 4) == 1
            attach!(res_path, CPW_hole_ref, (0.0um):(4um):(pathlength(res_path[hlp])), i=hlp)
        else
            attach!(res_path, CPW_hole_ref_offset1, (0.0um):(4um):(pathlength(res_path[hlp])), i=hlp)
        end
    else
        for hlp in 3:2:5
            if mod(hlp, 4) == 1
                attach!(res_path, CPW_hole_ref, (2.0um):(4um):(pathlength(res_path[hlp])+soi_trace/2+soi_gap+hole_extent), i=hlp)
            else
                attach!(res_path, CPW_hole_ref_offset1, (2.0um):(4um):(pathlength(res_path[hlp])+soi_trace/2+soi_gap+hole_extent), i=hlp)
            end
        end
        for hlp in 7:2:(length(res_path)-1)
            if mod(hlp, 8) == 7
                attach!(res_path, CPW_hole_ref_offset3, (2.0um):(4um):(pathlength(res_path[hlp])+soi_trace/2+soi_gap+hole_extent), i=hlp)
            elseif mod(hlp, 8) == 1
                attach!(res_path, CPW_hole_ref, (0.0um):(4um):(pathlength(res_path[hlp])+soi_trace/2+soi_gap+hole_extent), i=hlp)
            elseif mod(hlp, 8) == 3
                attach!(res_path, CPW_hole_ref_offset1, (2.0um):(4um):(pathlength(res_path[hlp])+soi_trace/2+soi_gap+hole_extent), i=hlp)
            elseif mod(hlp, 8) == 5
                attach!(res_path, CPW_hole_ref, (2.0um):(4um):(pathlength(res_path[hlp])+soi_trace/2+soi_gap+hole_extent), i=hlp)
            end
        end
        hlp = length(res_path)
        if mod(hlp, 4) == 1
            attach!(res_path, CPW_hole_ref, (0.0um):(4um):(pathlength(res_path[hlp])), i=hlp)
        else
            attach!(res_path, CPW_hole_ref_offset1, (0.0um):(4um):(pathlength(res_path[hlp])), i=hlp)
        end
    end
end


function PhS_unitcell_asym(c, ca=534nm, ctx=114nm, cty=114nm, chx=418nm, chy=418nm; mechaniclayer=MECHANIC_LAYER)
    #r0 = Rectangle(Point(-ca/2, -ca/2), Point(ca/2, ca/2))
    r1 = Rectangle(Point(-ctx / 2, -chy / 2), Point(ctx / 2, chy / 2))
    r2 = Rectangle(Point(-chx / 2, -cty / 2), Point(chx / 2, cty / 2))

    u = clip(ClipTypeUnion, r2, r1)[1]
    render!(c, u, GDSMeta(mechaniclayer))
end

## Make the whole qubit
# Claw coupler and capacitor
function make_qubit_cell(claw_length, qubit_length; jjlayer=JJ_LAYER, undercut_layer=UC_LAYER, mechaniclayer=MECHANIC_LAYER, qubitlayer=QUBIT0_LAYER)
    Qubit_cell = Cell(uniquename("Qubit_cell"), nm)
    Qubit_cap = Cell(uniquename("Qubit_cap"), nm)
    claw_cpl(Qubit_cell, soi_trace, soi_gap, claw_length, ground_gap, qubit_width, qubit_gap)
    qubit_cap(Qubit_cap, qubit_length, qubit_width, qubit_gap, qubit_cap_bottom_gap)
    push!(Qubit_cell.refs, CellReference(Qubit_cap, Point((qubit_length + qubit_gap + soi_trace + soi_gap + ground_gap), 0um), rot=pi / 2))

    # the JJs/SQUID
    SQUID = make_SQUID(w1, l1, w2, l2, w3, l3, w4, l4,
        pad_h, pad_w, bandaid_finger_h,
        bandaid_finger_w,
        squid_separation_bottom,
        0um, ca / 2,
        jjlayer=JJ_LAYER, undercut_layer=UC_LAYER, gnd_cutout_layer=GND_CUTOUT_LAYER, bandaid_layer=BANDAID_LAYER)

    # the PhS array for JJ
    Ph_unitcell = Cell(uniquename("Ph_unitcell"), nm)
    #PhS_unitcell_asym(c, ca=534nm, ctx=146nm, cty=146nm, chx=442nm, chy=442nm; mechaniclayer = MECHANIC_LAYER)
    PhS_unitcell_asym(Ph_unitcell, 534nm, 114nm, 114nm, 418nm, 418nm, mechaniclayer=mechaniclayer)
    Ph_array_cell = Cell(uniquename("Ph_array"), nm)
    Ph_array = CellArray(Ph_unitcell, (-10.5*ca):ca:(10.5*ca), (-10*ca):ca:(10*ca))
    push!(Ph_array_cell.refs, Ph_array)
    flatten!(Ph_array_cell)


    # Mechanical cell together with JJ
    JJ_membrane = Cell(uniquename("JJ_membrane"), nm)
    render!(JJ_membrane, centered(Rectangle(Point(-1.5 * ca, -1 * ca), Point(1.5 * ca, 1 * ca))), GDSMeta(JJ_MEMBRANE_LAYER))
    # put the no hole region covering JJ and phononic shield attached to JJ membrane
    render!(JJ_membrane, centered(Rectangle(Point(-9 * ca - no_hole_margin, -7.5 * ca - no_hole_margin), Point(9 * ca + no_hole_margin, 7.5 * ca + no_hole_margin))), GDSMeta(NO_HOLE_LAYER))
    # Phononic shield boundary
    PS_boundary = Cell(uniquename("PS_boundary"), nm)
    render!(PS_boundary, centered(Rectangle(Point(-10.5 * ca, -10 * ca), Point(10.5 * ca, 10 * ca))), GDSMeta(SHIELD_BOUNDARY_LAYER))

    # for the JJ above origin (left)
    push!(SQUID.refs, CellReference(JJ_membrane, Point(-(squid_separation_bottom) / 2, 0um)))
    push!(SQUID.refs, CellReference(PS_boundary, Point(-(squid_separation_bottom) / 2, 0um)))
    push!(SQUID.refs, CellReference(Ph_array_cell, Point(-(squid_separation_bottom) / 2, 0um)))
    # for the other JJ on the right
    push!(SQUID.refs, CellReference(JJ_membrane, Point((squid_separation_bottom) / 2, 0um)))
    push!(SQUID.refs, CellReference(Ph_array_cell, Point((squid_separation_bottom) / 2, 0um)))
    push!(SQUID.refs, CellReference(PS_boundary, Point((squid_separation_bottom) / 2, 0um)))


    push!(Qubit_cell.refs, CellReference(SQUID, Point((soi_trace + soi_gap + ground_gap + qubit_gap + qubit_length + qubit_cap_bottom_gap / 2), -0.55um), rot=-pi / 2))#Point((qubit_length+qubit_gap+soi_trace+soi_gap+ground_gap+qubit_cap_bottom_gap-pad_h+pad_overlap_with_ground + 1.5um), 0.0um), rot=pi/2))
    flatten!(Qubit_cell)

    # the additional layer to select between qubits
    render!(Qubit_cell, Rectangle(Point(50um + qubit_length, -25um), Point(120um + qubit_length, 25um)), GDSMeta(qubitlayer))

    return Qubit_cell
end

function make_bridge(c, staplefw, staplefh, staplespan; bridge_feet_layer=BRIDGE_FEET_LAYER, bridge_scaffold_layer=BRIDGE0_LAYER)
    render!(c, Rounded(1.0um)(Rectangle(Point(-staplespan / 2 - staplefw, -staplefh / 2 + 2um), Point(staplespan / 2 + staplefw, staplefh / 2 - 2um))), GDSMeta(bridge_feet_layer))
    render!(c, Rounded(1.0um)(Rectangle(Point(-staplespan / 2, -staplefh / 2), Point(staplespan / 2, staplefh / 2))), GDSMeta(bridge_scaffold_layer))
    return c
end

function consolidate_airbridge_offsets(path, init_offset, start_segment_index, end_segment_index; brg_sep=brg_sep_TL)
    offsets = []
    append!(offsets, init_offset)
    for i in start_segment_index:(end_segment_index-1)
        path_tmp = init_offset:brg_sep:pathlength(path[start_segment_index:i])
        if abs(path_tmp[end] - pathlength(path[start_segment_index:i])) < 10um
            current_offset = 0um
        else
            current_offset = path_tmp[end] + brg_sep - pathlength(path[start_segment_index:i])
        end
        append!(offsets, current_offset)
    end
    return offsets
end

function attach_airbridges(path, airbridge_offsets, start_segment_index, end_segment_index, sref; brg_sep=brg_sep_RO)
    # In order to coerce airbridges to follow curves in a path, the segments
    # must be simplified into one path element. Alternatively you could attach
    # to each path segment separately but that's annoying. Unfortunately you
    # cannot just simplify the entire path because the imported gds cells cause
    # the simplify function to throw errors, so you must target the CPW sections
    #simplify!(path, (start_segment_index:end_segment_index))
    for segment_index in range(start_segment_index, end_segment_index, step=1)
        attach!(path, sref, airbridge_offsets[segment_index-start_segment_index+1]:brg_sep:pathlength(path[segment_index]), i=segment_index)
    end
end
