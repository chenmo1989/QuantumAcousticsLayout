using Pkg
Pkg.activate(".")  # ensures the environment is used
using FileIO, DeviceLayout, DeviceLayout.PreferredUnits, DeviceLayout.SchematicDrivenLayout
import DeviceLayout: μm, nm
import DeviceLayout: uconvert

# define layers
CHIP_OUTLINE = 100
WRITEABLE_OUTLINE = 101
MARKER_LAYER = 102
LETTERS_LAYER = 102
MECHANICS_LAYER = 3
HF_HOLES_LAYER = 3
GROUND_PLANE = 4
JJ_LAYER = 5
UC_LAYER = 6
GROUND_PATT = 7
BANDAID_LAYER = 9
BRIDGE_FEET_LAYER = 9
NO_HOLE_LAYER = 20
JJ_MEMBRANE_LAYER = 21
GND_CUTOUT_LAYER = 22

# Define the chip dimensions
chip_height = 15mm
chip_width = 15mm
deadzone_width = 0.6mm
deadzone = deadzone_width * 2
writeable_width = chip_width - 2 * deadzone_width
writeable_height = chip_height - 2 * deadzone_width
die_height = 2mm
die_width = 2mm

# define baseline dimensions for mechanics
ca = 534nm
ct = 123nm
ch = 422nm

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
    render!(marker, (r1, r2, r3, r4, Polygons.union2d(r5, r6)), GDSMeta(MARKER_LAYER))

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
    render!(local_marker, r, GDSMeta(MARKER_LAYER))
    push!(die.refs, CellArray(local_marker, Point(-0.2mm, 0.2mm), dr=Point(0mm, -0.4mm), dc=Point(0.4mm, 0mm), nr=2, nc=2))
end

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

function add_dicing_cross(dev)
    # add dicing cross
    dicing_marker = Cell(uniquename("dicing_marker"))

    r = Polygons.union2d(centered(Rectangle(0.5mm, 0.05mm)), centered(Rectangle(0.05mm, 0.5mm)))
    render!(dicing_marker, r, GDSMeta(MARKER_LAYER))
    # top two
    push!(dev.refs, CellArray(dicing_marker, Point(-4mm, -4mm), dr=Point(0mm, die_height), dc=Point(die_width, 0mm), nr=5, nc=5))
    # bottom right (left side is for chip signature)
    push!(dev.refs, CellArray(dicing_marker, Point(1.5mm, -1.5mm), dr=Point(0mm, -3mm), dc=Point(3mm, 0mm), nr=1, nc=1))
end

function add_mechanics_test_pattern(dev)
    # central PhS (make it 3x3 in cjob layout)
    for xpos in 4:4
        for ypos in 4:4
            Ph_unitcell = Cell(uniquename("Ph_unitcell"), nm)
            PhS_unitcell_asym(Ph_unitcell, 534nm, 122nm + (xpos - 4) * 3nm * 2, 122nm + (ypos - 4) * 3nm * 2, 428nm + (xpos - 4) * 3nm * 2, 428nm + (ypos - 4) * 3nm * 2)
            #PhS_unitcell_asym(Ph_unitcell, ca=534nm, ctx=146nm, cty=146nm, chx=442nm, chy=442nm)
            Ph_array_cell = Cell(uniquename("Ph_array"), nm)
            Ph_array = CellArray(Ph_unitcell, Point(-8 * ca, 8 * ca), dr=Point(0mm, -ca), dc=Point(ca, 0mm), nr=16, nc=16)
            push!(Ph_array_cell.refs, Ph_array)
            flatten!(Ph_array_cell)

            push!(dev.refs, CellReference(Ph_array_cell, Point((xpos - 4) * 15μm, (ypos - 4) * 15μm), rot=0))
        end
    end
end

function main()
    # Chip
    device = Cell("device", nm)
    chip = centered(Rectangle(chip_width, chip_height))
    # Define rectangle that gets extruded to generate substrate volume
    # Define the EBPG 5200 writeable region
    writeable_region = centered(Rectangle(writeable_width, writeable_height) +
                                Point(deadzone_width, 0mm))
    add_global_marker!(device)
    add_chip_triangle(device)
    add_local_marker(device)
    add_chip_signature(device)
    add_dicing_cross(device)
    add_mechanics_test_pattern(device)

    render!(device, chip, GDSMeta(CHIP_OUTLINE))
    render!(device, writeable_region, GDSMeta(WRITEABLE_OUTLINE))

    flatten!(device)
    save(joinpath(@__DIR__, "ZEP_cal_SOI.gds"), device)
end

# run the code
main()

