# This script is for defining all relevant parameters

# define layers
# Layer labels
CHIP_OUTLINE = 0
WRITEABLE_OUTLINE = 1
# these two are new layers MC defined
MARKER_LAYER = 2
#####################
HF_HOLE_LAYER = 3
GROUND_PLANE = 4
GROUND_PATT = 7
BANDAID_LAYER = 9
BRIDGE_FEET_LAYER  = 9
PATCH  = 9
LETTERS_LAYER = 80
NO_HOLE_LAYER = 20
GND_CUTOUT_LAYER = 10

JJ_LAYER = 5
UC_LAYER = 6
MECHANIC_LAYER = 11
JJ_MEMBRANE_LAYER = 12

JJ_TEST_LAYER = 21
UC_TEST_LAYER = 22
MECHANIC_TEST_LAYER = 23

QUBIT0_LAYER = 30
QUBIT1_LAYER = 31
QUBIT2_LAYER = 32
QUBIT3_LAYER = 33
QUBIT4_LAYER = 34

BRIDGE0_LAYER = 40

SHIELD_BOUNDARY_LAYER = 50

# Define the chip dimensions
chip_height = 1cm
chip_width = 2cm
deadzone_width = 0.6mm
deadzone = deadzone_width*2
writeable_width = chip_width - 2*deadzone_width
writeable_height = chip_height

# Define geometry
gap_adjust = 0nm
# CPW on SOI
soi_trace = 38.0um
soi_gap = 4.0um - gap_adjust
res_trace = 38.0um
res_gap = 4.0um

# Launcher parameters
launcher_margin = 450um
launcher_spacing = 2mm
soi_launch_params = Dict(
    :gap0 => 100um,
    :gap1 => soi_gap,
    :trace0 => 345um,
    :trace1 => soi_trace,
    :flatlen => 250μm,
    :taperlen => 250μm
    )

launcher_length = soi_launch_params[:gap0] + soi_launch_params[:flatlen] +
                    soi_launch_params[:taperlen]
launcher_width = 2 * soi_launch_params[:gap1] + soi_launch_params[:trace0]

# Phononic shield
ca=534nm
#ct=169nm
#ch=503nm

# Resonators
gndOffRes = 2.0μm + gap_adjust*2 #ground plane length between the the gaps of the feedline and resonator CPW
turnRadRes = 113.0μm #radius of turning circle when meandering
ResStraight = 520.0μm # just the length of a straight segment of a meander
Res_coupling = 250.0μm #length of resonator wire next to feedline-->proportional to coupling between feedline and wire
# capacitive_gap=2μm;

# Style definitions
cpw_style = Paths.CPW(soi_trace, soi_gap)
cpw_blank = Paths.CPW(0nm, 0nm)
cpw_style_gap = Paths.CPW(0um, soi_trace/2+soi_gap)
res_style = Paths.CPW(res_trace, soi_gap)
res_style_gap = Paths.CPW(0um, res_trace/2+res_gap)

# Qubit capacitor
qubit_length = 600um
qubit_width = 30um
qubit_gap = 30um
qubit_cap_bottom_gap = 12um
claw_length = 300um
ground_gap = 2um

# Junction parameters
Θ = 30.0° #first evaporation angle
ϕ = 30.0° #second evaporation angle
t1 = 450nm #undercut height (i.e. copolymer layer thickness)
t2 = 0nm
Δ_w1, Δ_w2 = 0nm, 0nm

uc = 0.0nm # uc: safety margin (additional undercut beyond what is needed from geometry)
uuc = uc + t1*tan(Θ) #vertical undercut for first evaporation
ruc = uc + t1*tan(ϕ) #horizontal undercut for second evaporation
jj_membrane_margin = 100nm
w1 = 35nm
w2 = 1352nm - ruc
l2 = 818nm - uuc
#w2 = ca*3 - ruc - jj_membrane_margin*2
#l2 = ca*2 - uuc - jj_membrane_margin*2
w3 = 5.634um
l3 = w1
w4 = 0.3um
pad_margin = 0.5um
pad_w = 7.5um
pad_h = 2um #pad height, pad width; where the pad is the thickness of the JJ loop (besides the areas of small features)
#l1 = qubit_cap_bottom_gap/2 - l2/2 - (pad_h - pad_overlap_with_ground) +1.5um
#l4 = qubit_cap_bottom_gap/2 + l3/2 - (pad_h - pad_overlap_with_ground) +1.5um
l1 = 20um
l4 = 11um + l3/2
jj_height = l1+l2/2-l3/2+l4
w1_widen = 100nm

bandaid_finger_w, bandaid_finger_h = 0.1um, 2um #bandaid finger parameters
bandaid_margin = 0.5um
gnd_cutout_margin = 150nm
#bandaid_width = bandaid_finger_h + t1*tan(Θ)
squid_separation_bottom = 12.4um #separation between JJ pads in SQUID # was 5um
#squid_separation_top = squid_separation_bottom + (pad_w/2 - (w2/2+w3+w4)) * 2

# HF release holes
no_hole_margin = 2um # additional margin to account for misalignment
#hole_radius = 150nm
hole_radius = 50nm
hole_extent = 100um # this is the parameter that sets the width of the undercut region.
hole_spacing = 4um

# BRIDGE DEFINITION
staplespan = 58um
staplefw = 14um
staplefh = 10um
brg_sep_RO = 1000um
brg_sep_TL = 1200um
dbbrg_dist = 40um
brg_turnSep = 20um
