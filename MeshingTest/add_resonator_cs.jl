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
deadzone_width=0.3mm
deadzone_height=0mm
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

chip = centered(Rectangle(chip_width, chip_height))

place!(device, chip, LayerVocabulary.CHIP_AREA)

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

place!(device, TL_path, LayerVocabulary.METAL_NEGATIVE)


########################################
########Turn to Solid Model#############
########################################

"""
Map SemanticMeta(:some_layer) -> GDSMeta(layer, datatype) using CQEDPDK.LAYER_RECORD.

- Passes through GDSMeta unchanged.
- Returns NORENDER_META unchanged (so DeviceLayout can skip it).
- Errors on unknown SemanticMeta keys (good for catching typos).
"""
function map_meta_from_layer_record(m)
	# Let already-concrete GDS metadata pass through.
	m isa GDSMeta && return m

	# If you rely on NORENDER_META anywhere:
	m === DeviceLayout.NORENDER_META && return m

	# Only handle SemanticMeta
	if m isa SemanticMeta
		k = layer(m)  # should be :metal_negative, :junction, etc.
		haskey(LAYER_RECORD, k) || error("map_meta: SemanticMeta($k) not in LAYER_RECORD")
		rec = LAYER_RECORD[k]
		return GDSMeta(layer(rec), datatype(rec))
	end

	# If you also have other Meta types, either pass-through or decide a policy:
	error("map_meta: don't know how to map metadata of type $(typeof(m)): $m")
end

c = Cell("test02", nm)

#render!(c, device; map_meta = map_meta_from_layer_record)
render!(c, device, L1_TARGET, strict = :no, simulation = false)
flatten!(c)
save(joinpath(@__DIR__, "test02.gds"), c)

# Need to pass generated physical group names so they can be retained
tech = CQEDPDK.singlechip_solidmodel_target()
sm = SolidModel("test", overwrite = true)

# Adjust mesh_scale to increase the resolution of the mesh, < 1 will result in greater
# resolution near edges of the geometry.
meshing_parameters = SolidModels.MeshingParameters(
	mesh_scale = 1.0,
	α_default = 0.9,
	mesh_order = 2,
	options = Dict("General.Verbosity" => 1.0), # General Gmsh option input
)

place!.(device, offset(bounds(device), 200μm), :substrate)
place!(device, bounds(device), :simulated_area)
zmap = (m) -> layer(m) == :simulated_area ? -1000μm : 0μm
postrender_ops = [
	("substrate_extrusion", SolidModels.extrude_z!, ("substrate", -500μm))
	("simulated_area_extrusion", SolidModels.extrude_z!, ("simulated_area", 2000μm))
	("metal", SolidModels.difference_geom!, ("substrate", "metal_negative"))
]

SolidModels.gmsh.option.setNumber("General.Verbosity", 0)
render!(sm, device; zmap = zmap, postrender_ops = postrender_ops);
SolidModels.gmsh.model.mesh.generate(3)
SolidModels.gmsh.fltk.run()

# SolidModels.gmsh.option.set_number("General.NumThreads", 1) # Force single-threaded (deterministic) meshing
#SolidModels.gmsh.model.mesh.generate(3) # runs without error
save(joinpath(@__DIR__, "test02.msh2"), sm)

