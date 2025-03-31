using Pkg
Pkg.activate(".")  # ensures the environment is used
using FileIO, CSV, DataFrames, JSON, JSONSchema
using DeviceLayout, DeviceLayout.PreferredUnits, DeviceLayout.SchematicDrivenLayout
import DeviceLayout: μm, nm
import .SchematicDrivenLayout.ExamplePDK
import .SchematicDrivenLayout.ExamplePDK: LayerVocabulary, L1_TARGET, ASSEMBLY_TARGET, add_bridges!
using .ExamplePDK.Transmons, .ExamplePDK.ReadoutResonators, .ExamplePDK.ChipTemplates
import .ExamplePDK.SimpleJunctions: ExampleSimpleJunction
import DeviceLayout: uconvert
using PRIMA

function assemble_schematic_graph(g)

end
    
function TransmissionLine(g)
    p_feedline = Path(Point(-1350μm, 0μm) - Point(650μm,0μm); α0 = 0, metadata=LayerVocabulary.METAL_NEGATIVE) # 650μm is the length of the launcher
    sty = launch!(p_feedline)
    straight!(p_feedline, 2700μm, sty)
    launch!(p_feedline)
    p_feedline_node = add_node!(g, p_feedline)
    return g, p_feedline_node
end

g = SchematicGraph("simplechip")
# Feedline
g, p_feedline_node = TransmissionLine(g)
## Resonator
rres = ExampleClawedMeanderReadout()
rres_node1 = add_node!(g, rres)
rres_node2 = add_node!(g, rres)
rres_node3 = add_node!(g, rres)
attach!(g, p_feedline_node, rres_node2 => :feedline, 1.35mm, i=4, location=-1)
attach!(g, p_feedline_node, rres_node1 => :feedline, 0.7mm, i=4, location=1)
attach!(g, p_feedline_node, rres_node3 => :feedline, 2mm, i=4, location=1)

@time "Floorplanning" floorplan = plan(g)
# Chip
center_xyz = DeviceLayout.center(floorplan)
chip = centered(Rectangle(5mm, 5mm), on_pt = Point(0mm,0mm))#center_xyz)
# Define rectangle that gets extruded to generate substrate volume
render!(floorplan.coordinate_system, chip, LayerVocabulary.CHIP_AREA)

check!(floorplan)

artwork = Cell("simplechip") # "artwork" = "pattern used for fabrication"
@time "Rendering to polygons" render!(artwork, floorplan, ASSEMBLY_TARGET)
#render!(g, identity, strict=:no, simulation=true)
flatten!(artwork)
save(joinpath(@__DIR__, "simple_chip.gds"), artwork)