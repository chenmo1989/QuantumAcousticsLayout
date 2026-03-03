using DeviceLayout, DeviceLayout.PreferredUnits
using FileIO
import DeviceLayout: μm, nm
import DeviceLayout: uconvert
import DeviceLayout: flushtop, flushleft, flushright, below, above

using CQEDPDK
import CQEDPDK.LAYER_RECORD
using CQEDPDK.ChipTemplates_CQED, CQEDPDK.ReadoutResonators_CQED

########################################
###########Define the Chip##############
########################################

## Define parameters
# Dictionary for keyword parameters. This makes the function call much cleaner!
chip_param = Dict(
	:chip_width => 5mm,
	:chip_height=>5mm,
	:deadzone_width=>0.3mm,
	:deadzone_height=>0mm,
	:cutout_width=>300μm,
	:cutout_height=>100μm,
)

## Build chip
design_name = "WAS01"
device = Cell(design_name, nm)

ChipTemplates_CQED.build_device!(device; chip_param...)

########################################
########Add Transmission Line###########
########################################

## Define parameters
cpw_style = Paths.SimpleCPW(10µm, 6μm)
launch_param = Dict(
	:extround => 0.0μm,
	:trace0 => 200.0μm,
	:trace1 => 10.0μm,
	:gap0 => 130.0μm,
	:gap1 => 6.0μm,
	:flatlen => 200.0μm,
	:taperlen => 150.0μm,
)

## Create transmission line
(ptL, αL) = ChipTemplates_CQED.launcher_site(16)
(ptR, αR) = ChipTemplates_CQED.launcher_site(5)

readout_length = abs(ptR.x - ptL.x) - (launch_param[:gap0] + launch_param[:flatlen] + launch_param[:taperlen]) * 2 # length of launcher is 650μm

TL_path = Path(
	ptL + Point(launch_param[:gap0], 0.0μm), # 150μm is the "gap" behind the bonding pad
	α0 = αL,
	name = "p_ro",
	metadata = LAYER_RECORD.metal_negative,
)

launch!(TL_path; launch_param...)
straight!(TL_path, readout_length, cpw_style)
launch!(TL_path; launch_param...)

render!(device, TL_path, LAYER_RECORD.metal_negative)

########################################
########Add Readout Resonator###########
########################################

## Define parameters
# these are separated and not directly defined in res_param because they are used both for resonator and for qubit
w_shield=2μm
w_claw = 35μm
claw_gap = 6μm
etch_bias_LL = 0nm

res_param = Dict(
	:total_length=>4860μm,
	:coupling_length=>400μm,
	:coupling_gap=>5μm,
	:bend_radius=>50μm,
	:n_meander_turns=>5,
	:total_height=>1450μm,
	:hanger_length=>500μm,
	:w_shield => w_shield,
	:claw_gap => claw_gap,
	:w_claw => w_claw,
	:etch_bias_LL => etch_bias_LL,
)

## Create resonator
TL_path = Path(Point(0μm, 0μm), α0 = 0,
	name = "p_tl",
	metadata = LAYER_RECORD.metal_negative,
)
ReadoutResonators_CQED.build_transmission_line!(TL_path, 16; cpw_style = cpw_style, launch_param = launch_param)

(ptL, αL) = ChipTemplates_CQED.launcher_site(16)

RO1_path = Path(
	ptL + Point(1500μm, 0μm),
	α0 = αL)
ReadoutResonators_CQED.create_resonator!(
	RO1_path; cpw_style = cpw_style, res_param...,
)

render!(device, RO1_path, LAYER_RECORD.metal_negative)

save(joinpath(@__DIR__, "test03.gds"), device)
