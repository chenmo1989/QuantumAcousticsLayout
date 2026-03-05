using DeviceLayout, DeviceLayout.PreferredUnits, DeviceLayout.SchematicDrivenLayout
using FileIO
import DeviceLayout: μm, nm
import DeviceLayout: uconvert
import DeviceLayout: flushtop, flushleft, flushright, below, above

using CQEDPDK
import CQEDPDK: LayerVocabulary, SINGLECHIP_SOLIDMODEL_TARGET, L1_TARGET
import CQEDPDK.LAYER_RECORD
using CQEDPDK.ChipTemplates_CQED

########################################
###########Define the Chip##############
########################################

## Define parameters
chip_width=5mm
chip_height=5mm
deadzone_width=0.1mm
deadzone_height=0.1mm
cutout_width=300μm
cutout_height=100μm

## Build chip
design_name = "WAS01"
device = CoordinateSystem(design_name, nm)

"""
ChipTemplates_CQED.build_device!(device;
	chip_width = chip_width,
	chip_height = chip_height,
	deadzone_width = deadzone_width,
	deadzone_height = deadzone_height,
	cutout_width = cutout_width,
	cutout_height = cutout_height,
)

"""
## to Simplify things for building the mesh and for palace model
chip = centered(Rectangle(chip_width, chip_height))

place!(device, (chip), LayerVocabulary.CHIP_AREA)
#place!(device, chip, LayerVocabulary.NORENDER_META)

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
	metadata = LayerVocabulary.METAL_NEGATIVE,
)

launch!(TL_path; extround = 0.0μm,
	trace0 = 200.0μm,
	trace1 = 10.0μm,
	gap0 = 130.0μm,
	gap1 = 6.0μm,
	flatlen = 200.0μm,
	taperlen = 150.0μm)
straight!(TL_path, readout_length, cpw_style)
launch!(TL_path; launch_param...)

csport = CoordinateSystem(uniquename("port"), nm)
render!(
	csport,
	only_simulated(centered(Rectangle(cpw_style.trace, cpw_style.trace))),
	LayerVocabulary.PORT,
)
# Attach with port center `cpw_width` from the end (instead of `cpw_width/2`) to avoid corner effects
attach!(TL_path, sref(csport), cpw_style.trace, i = 4) # @ start
attach!(TL_path, sref(csport), readout_length / 2 - cpw_style.trace, i = 4) # @ end

place!(device, TL_path, LayerVocabulary.METAL_NEGATIVE)
########################################
########Add Readout Resonator###########
########################################

## Define parameters
total_length=4860μm
coupling_length=400μm
coupling_gap=5μm
bend_radius=50μm
n_meander_turns=5
total_height=1450μm
hanger_length=500μm
w_shield=2μm
w_claw = 35μm
claw_gap = 6μm

## Create resonator
RO_path = Path(
	ptL + Point(-coupling_length / 2, -coupling_gap - cpw_style.gap * 2 - cpw_style.trace) +
	Point(1500μm, 0μm),
	α0 = αL,
)

n_bends = 3 + 2 * n_meander_turns # nμmber of 90 degree bends
arm_length = (
	total_height - hanger_length - n_bends * bend_radius - coupling_gap - cpw_style.gap - cpw_style.trace / 2 - w_shield - 2 * claw_gap - w_claw
)
# Length of straight sections in meander
straight_length =
	(
		total_length - 3 * coupling_length / 2 - n_bends * pi * bend_radius / 2 -
		arm_length - hanger_length
	) / n_meander_turns

straight!(RO_path, coupling_length, cpw_style)
turn!(RO_path, -90°, bend_radius)
straight!(RO_path, hanger_length)
turn!(RO_path, -90°, bend_radius)
# Center of the straight section of meander lines up with coupling midpoint (and claw)
straight!(RO_path, straight_length / 2 + coupling_length / 2)
turn!(RO_path, 180°, bend_radius)

# Start the meander with a full straight section
meander_length =
	(n_meander_turns - 1) * (straight_length + pi * bend_radius) + straight_length / 2 -
	bend_radius
meander!(RO_path, meander_length, straight_length, bend_radius, -180°)
turn!(RO_path, -90°, bend_radius)
straight!(RO_path, arm_length)
terminate!(RO_path) # for simulation purpose, since we do not have the claw/qubit to terminate it.

place!(device, RO_path, LayerVocabulary.METAL_NEGATIVE)

############Bounding the simulation area############
place!(device, centered(Rectangle(readout_length / 2, 3mm), on_pt = Point(-0.91mm, 0.85mm)), LayerVocabulary.SIMULATED_AREA)

c = Cell("test02", nm)
render!(c, device, L1_TARGET, strict = :no, simulation = true)
flatten!(c)
save(joinpath(@__DIR__, "test02.gds"), c)

########################################
########Turn to Solid Model#############
########################################
zmap = (m) -> layer(m) == :simulated_area ? -1000μm : 0μm
postrender_ops = [
	("substrate_extrusion", SolidModels.extrude_z!, ("chip_area", -500μm))
	("simulated_area_extrusion", SolidModels.extrude_z!, ("simulated_area", 2000μm))
	("metal", SolidModels.difference_geom!, ("chip_area", "metal_negative"))
]

sm = SolidModel("test"; overwrite = true)
#SolidModels.gmsh.option.setNumber("General.Verbosity", 0)
render!(sm, device; zmap = zmap);
SolidModels.gmsh.fltk.run()
SolidModels.gmsh.model.mesh.generate()

"""
# Adjust mesh_scale to increase the resolution of the mesh, < 1 will result in greater
# resolution near edges of the geometry.
meshing_parameters = SolidModels.MeshingParameters(
	mesh_scale = 1.0,
	α_default = 0.9,
	mesh_order = 2,
	options = Dict("General.Verbosity" => 1.0), # General Gmsh option input
)

save(joinpath(@__DIR__, "test02.msh2"), sm)
"""
