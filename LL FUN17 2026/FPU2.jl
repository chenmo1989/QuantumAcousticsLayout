using DeviceLayout, DeviceLayout.PreferredUnits, FileIO, Dates, Clipper
const um = μm   # optional, keeps your old code unchanged
const pi = π

include(joinpath(@__DIR__, "parameter_def_minimize_hatch.jl"))
include(joinpath(@__DIR__, "make_NQ_minimize_hatch.jl"))

# This script generates either
# 1. directly things to be used, not subject to frequent change, or
# 2. building blocks for things I constantly tinker
# Markers
# Firstly array for bundle of 3 markers, then array them between launchers
function generate_markers(dev)
    marker = typeof(device)(uniquename("marker"))
    render!(marker, centered(Rectangle(20um, 20um)), GDSMeta(MARKER_LAYER))

    tile = Cell("marker_tile", nm)

    push!(tile.refs,
        CellArray(marker, Point(0um, 0um);
            dr=Point(0um, 500um),
            dc=Point(500um, 0um),
            nr=1, nc=3)
    )

    push!(dev.refs,
        CellArray(tile, Point(2500um, 500um);
            dr=Point(0um, 9mm),
            dc=Point(2mm, 0um),
            nr=2, nc=8)
    )
    local_marker = Cell("local_marker", nm)
    push!(local_marker.refs, CellArray(marker, Point(0um, -250um), dr=Point(0um, 500um), dc=Point(100um, 0um), nr=2, nc=4))
    #push!(local_marker.refs, CellArray(marker, Point(0um, -350um), dr = Point(0um, 700um), dc = Point(100um, 0um), nr=2, nc=4))
    push!(dev.refs, CellReference(local_marker, Point(7.1805mm + 0.6195mm, 6.704mm), rot=0)) # RO1
    push!(dev.refs, CellReference(local_marker, Point(9.1795mm + 0.6195mm, 3.296mm), rot=0)) # RO2
    push!(dev.refs, CellReference(local_marker, Point(11.1805mm + 0.6195mm, 6.704mm), rot=0)) # RO3
    push!(dev.refs, CellReference(local_marker, Point(13.1795mm + 0.6195mm, 3.296mm), rot=0)) # RO4
end
## need flatten!

function add_chip_signature(dev)
    chip_signature = Cell(uniquename("chip_markup"))
    PolyText.polytext!(chip_signature, "ZEP cal SOI\nCQED Lab @ UW", DotMatrix(; pixelsize=25μm, rounding=6μm))
    push!(dev.refs, CellReference(chip_signature, Point(-4.5mm, -5.5mm)))
end

function add_chip_triangle!(dev)
    triangle = Cell(uniquename("triangle"))
    render!(triangle, Polygon(Point(-525µm / 2, 0µm), Point(525µm / 2, 0µm), Point(0µm, 750µm)), GDSMeta(MARKER_LAYER))
    push!(dev.refs, CellReference(triangle, Point(-4.5mm, -5mm)))
    return dev
end

function assemble_chip(device)
    # Transmission Line
    TL1_launcher_index = 2
    TL1_launcher_xpos = TL1_launcher_index * launcher_spacing
    TL1_launcher_ypos = chip_height - (launcher_margin)
    TL1_path = Path(Point(TL1_launcher_xpos, TL1_launcher_ypos), α0=-pi / 2)
    style = launch!(TL1_path; soi_launch_params...)
    straight!(TL1_path, 1.95mm, style)
    turn!(TL1_path, pi / 2, 2mm)
    straight!(TL1_path, launcher_spacing * 4)
    turn!(TL1_path, pi / 2, 2mm)
    straight!(TL1_path, 1.95mm)
    launch!(TL1_path; soi_launch_params...)

    # function for Z path
    function generate_Zline_instructions(path, style, instructions)
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
                straight!(path, 200um, Paths.Taper())
                straight!(path, 100um, Paths.CPW(7.2um, 0.8um))
                straight!(path, 50um)
                flux_bias_cell = Cell(uniquename("flux_bias"), nm)
                flux_bias!(flux_bias_cell, "r", 10um, 4um, 9um, 7.2um, 0.8um, GDSMeta(GROUND_PLANE)) # flux_over, flux_under, flux_cut, z_trace, z_gap,
                flux_bias_cell_ref = CellReference(flux_bias_cell, Point(0um, 0um), rot=-pi / 2)
                attach!(path, flux_bias_cell_ref, 50um, i=length(path))
            end
        end
    end

    function generate_XYline_instructions(path, style, instructions)
        # 'straight' instructions are parameterized by the length of straight cpw to
        #     append
        # 'turn' instructions are parameterized by the angle to turn and the radius of
        #     the turn
        for instruction in instructions
            if instruction[1] == "straight1"
                straight!(path, instruction[2], style)
            elseif instruction[1] == "turn"
                turn!(path, instruction[2], instruction[3])
                straight!(path, 200um)
                straight!(hole_path, 200um, cpw_blank)
                #straight!(hole_path, instruction[3], cpw_blank)
                #turn!(hole_path, instruction[2], 1nm, cpw_blank)
                #straight!(hole_path, instruction[3], cpw_blank)
            elseif instruction[1] == "straight2"
                straight!(path, instruction[2])
            elseif instruction[1] == "endXY"
                straight!(path, 200um, Paths.Taper())
                straight!(path, 100um, Paths.CPW(13um, 1um))
                straight!(path, 2um, Paths.Trace(15um))
            end
        end
    end


    # Resonators
    # RO1: 7.85GHz
    RO1_location = Point(6528um + 116um, 5048um)
    RO1_path = Path(RO1_location, α0=0)
    RO1_hole_path = Path(RO1_location, α0=0)

    #create_resonator(RO1_path, 205um, RO1_hole_path, 1)
    create_resonator(RO1_path, 503um, RO1_hole_path, 1)

    # add qubit
    Qubit_cell = make_qubit_cell(225um, 600um; jjlayer=JJ_LAYER, undercut_layer=UC_LAYER, mechaniclayer=MECHANIC_LAYER, qubitlayer=QUBIT1_LAYER)
    attach!(RO1_path, CellReference(Qubit_cell), pathlength(RO1_path[end]))
    # add additional length for RO1_hole_path to cover qubit
    straight!(RO1_hole_path, soi_gap + soi_trace + ground_gap + qubit_gap + qubit_length + qubit_cap_bottom_gap)
    attach!(RO1_hole_path, qubit_hole_ref_offset2, (0.5um-104um):(hole_spacing):(pathlength(RO1_hole_path[end])+hole_extent), i=length(RO1_hole_path))

    # Z line
    Z1_launcher_index = 5
    Z1_launcher_xpos = Z1_launcher_index * launcher_spacing
    Z1_launcher_ypos = TL1_launcher_ypos
    Z1_launcher_location = Point(Z1_launcher_xpos, Z1_launcher_ypos)
    Z1_path = Path(Z1_launcher_location, α0=-pi / 2)
    Z1_hole_path = Path(Z1_launcher_location - Point(0um, launcher_length), α0=-pi / 2)
    style = launch!(Z1_path; soi_launch_params...)
    Z1_instructions = [
        ["straight", 730um + 16um],
        ["turn", -pi / 2, 1500um],
        ["straight", 109.2um - (bandaid_finger_h + pad_h - 0.5um) + 150um - uuc],
        ["endZ"]
    ]

    XY1_launcher_index = 4
    XY1_launcher_xpos = XY1_launcher_index * launcher_spacing
    XY1_launcher_ypos = TL1_launcher_ypos
    XY1_launcher_location = Point(XY1_launcher_xpos, XY1_launcher_ypos)
    XY1_path = Path(XY1_launcher_location, α0=-pi / 2)
    XY1_hole_path = Path(XY1_launcher_location - Point(0um, launcher_length), α0=-pi / 2)
    style = launch!(XY1_path; soi_launch_params...)
    XY1_instructions = [
        ["straight1", 416um - 12um],
        ["turn", -pi / 6, 1000um],
        ["turn", pi / 6, 1000um],
        ["straight2", 38um - 20.217um],
        ["endXY"]
    ]
    generate_Zline_instructions(Z1_path, cpw_style, Z1_instructions)
    generate_XYline_instructions(XY1_path, style, XY1_instructions)
    flatten!(device)

    chip = Rectangle(chip_width, chip_height)

    # Define the EBPG 5200 writeable region
    writeable_region = Rectangle(writeable_width, writeable_height) +
                       Point(deadzone_width, 0um)

    render!(device, chip, GDSMeta(CHIP_OUTLINE))
    render!(device, writeable_region, GDSMeta(WRITEABLE_OUTLINE))
    render!(device, TL1_path, GDSMeta(GROUND_PLANE))
    render!(device, RO1_path, GDSMeta(GROUND_PLANE))
    render!(device, Z1_path, GDSMeta(GROUND_PLANE))
    render!(device, XY1_path, GDSMeta(GROUND_PLANE))
end

function main()
    # Define the primary cell for the device
    device = Cell("device", nm)

    #generate_markers(device)
    add_chip_signature(device)
    add_chip_triangle!(device)
    assemble_chip(device)
    #=== Save the generated GDS ===#
    filename = Dates.format(today(), "mmddyyyy") * "_test_qubit.gds"
    save_path = joinpath(save_dir, filename)

    save(joinpath(@__DIR__, filename), device)
end

main()