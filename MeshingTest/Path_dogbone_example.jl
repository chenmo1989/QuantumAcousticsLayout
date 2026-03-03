using DeviceLayout, DeviceLayout.PreferredUnits
using FileIO # You will have to add FileIO to the environment if you haven't already

r = centered(Rectangle(20μm, 40μm))
# Create a second rectangle rotated by 90 degrees, positioned below the first
r2 = Align.below(Rotation(90°)(r), r, centered = true) # centered in x-coordinate
r3 = Align.above(r2, r) # Another copy of r2 above the first rectangle
dogbone = union2d([r, r2, r3]) # Boolean union of the three rectangles as a single entity
rounded_dogbone = Rounded(4μm)(dogbone) # Apply the Rounded style

cr = Cell("dogbone", nm)
render!(cr, rounded_dogbone, GDSMeta(1))

## use CoordinateSystem
cref = sref(cr, Point(0.0μm, 0.0μm)) # sref is short for "structure [or single] reference"
p = Path(μm, metadata = GDSMeta())
sty = launch!(p)
straight!(p, 500μm, sty)
turn!(p, π / 2, 150μm)
straight!(p, 500μm)
launch!(p)
turnidx = Int((length(p) + 1) / 2) - 1 # the first straight segment of the path
simplify!(p, turnidx .+ (0:2))
attach!(p, cref, (60μm):(60μm):((pathlength(p[turnidx]))-60μm), i = turnidx)
c = Cell("decoratedpath", nm)
render!(c, p)
refs(c)

c_wrapper = Cell("wrapper", nm)
addref!(c_wrapper, sref(c, rot = 90°))

## alternatively
csr = CoordinateSystem("dogbone", nm)
place!(csr, rounded_dogbone, SemanticMeta(:bridge))
elements(csr)[1]

csref = sref(csr, Point(0.0μm, 0.0μm))
p = Path(nm, metadata = SemanticMeta(:metal_negative))
sty = launch!(p, trace1 = 4μm, gap1 = 4μm)
straight!(p, 500μm, sty)
turn!(p, π / 2, 150μm)
straight!(p, 500μm)
launch!(p, trace1 = 4μm, gap1 = 4μm)
turnidx = Int((length(p) + 1) / 2) - 1 # the first straight segment of the path
simplify!(p, turnidx .+ (0:2))
attach!(p, csref, (60μm):(60μm):((pathlength(p[turnidx]))-60μm), i = turnidx)
cs = CoordinateSystem("decoratedpath", nm)
addref!(cs, p) # either render! or place! would do the same thing here
refs(cs)

layer_record = Dict(:bridge => GDSMeta(1), :metal_negative => GDSMeta())
cell = Cell(cs; map_meta = m -> layer_record[layer(m)])
# Could also say cell = render!(Cell("newcell", nm), cs; map_meta=...)
