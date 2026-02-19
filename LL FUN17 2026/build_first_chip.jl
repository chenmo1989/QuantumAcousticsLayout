using Pkg
Pkg.activate(".")  # ensures the environment is used
using FileIO, DeviceLayout, DeviceLayout.PreferredUnits
import DeviceLayout: μm, nm
import DeviceLayout: uconvert

##########################################################
##############define CONSTANT/parameters##################
##########################################################




##########################################################
#############define subroutines/functions#################
##########################################################
function build_device!(device; chip_width=5mm, chip_height=5mm,
    deadzone_width=0.3mm, deadzone_height=0mm)

    chip = centered(Rectangle(chip_width, chip_height))

    writeable_width = chip_width - 2 * deadzone_width
    writeable_height = chip_height - 2 * deadzone_height

    writeable_region =
        centered(Rectangle(writeable_width, writeable_height) +
                 Point(deadzone_width, deadzone_height))

    render!(device, chip, LAYER_RECORD.chip_area)
    render!(device, writeable_region, LAYER_RECORD.writeable_area)

    return chip   # optional
end

"""
    launcher_site(id; L=5mm, n=4, c=925μm, e=200μm)

Return (pt, α0) for launcher site `id` in 1..16 on a square chip centered at (0,0).
α0 is the direction the feedline should initially point *into the chip*.

Numbering (n=4 per side):
1-4   top    (left→right)
5-8   right  (top→bottom)
9-12  bottom (right→left)
13-16 left   (bottom→top)
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