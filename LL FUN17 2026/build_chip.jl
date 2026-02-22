using DeviceLayout, DeviceLayout.PreferredUnits
using FileIO

design_name = "WAS01"
device = Cell(design_name, nm)

chip_width=5mm
chip_height=5mm
deadzone_width=0.3mm
deadzone_height=0mm
cutout_width=300μm
cutout_height=100μm

chip = centered(Rectangle(chip_width, chip_height))

writeable_width = chip_width - 2 * deadzone_width
writeable_height = chip_height - 2 * deadzone_height

writeable_region =
    centered(Rectangle(writeable_width, writeable_height) +
                Point(deadzone_width, deadzone_height))
cutout = Align.flushbottom(Align.flushleft(Rectangle(cutout_height, cutout_width), chip), chip)

render!(device, chip, GDSMeta(703, 0))
render!(device, writeable_region, GDSMeta(704, 0))
render!(device, difference2d(chip, cutout), GDSMeta(703, 1))

save(joinpath(@__DIR__, "test00.gds"), device)
