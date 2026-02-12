#### Utility to generate a "false color" layout based on component types
# Modifies `schematic` directly, returns a `Cell`
function false_color_layout!(schematic)
    pathrole(role) = function (comp)
        return (comp isa Path || comp isa RouteComponent) &&
               contains(lowercase(name(comp)), role)
    end
    layers = [
        ExampleStarTransmon => GDSMeta(0),
        pathrole("coupler") => GDSMeta(1),
        ExampleFilteredHairpinReadout => GDSMeta(2),
        pathrole("readout") => GDSMeta(2), # transmon "readout_coupler" path segment
        ExamplePDK.Transmons.ExampleXYTermination => GDSMeta(3),
        ExamplePDK.Transmons.ExampleZTermination => GDSMeta(4),
        pathrole("xy") => GDSMeta(3),
        pathrole("z") => GDSMeta(4),
        pathrole("ro") => GDSMeta(5),
        ExampleSeriesClawCapacitor => GDSMeta(5)
    ]
    ignore_layers = [CHIP_AREA, BRIDGE, BRIDGE_BASE, JUNCTION_PATTERN]
    for (condition, ly) in layers
        nodes_idx = find_components(condition, schematic.graph)
        for comp in component.(schematic.graph[nodes_idx])
            map_metadata!(comp, (m) -> (m in ignore_layers ? m : ly))
        end
    end
    halos = halo(schematic, 0μm; ignore_layers=ignore_layers)
    c = Cell(halos; map_meta=m -> (m isa SemanticMeta ? nothing : m))
    c.name = "false_color_layout"
    return c
end
