using Pkg
Pkg.activate(".")  # ensures the environment is used
using DeviceLayout, DeviceLayout.PreferredUnits, FileIO

cr = Cell("rect", nm)
r = centered(Rectangle(20μm, 40μm))
render!(cr, r, GDSMeta(1, 0))
save("units_rectonly.svg", cr; layercolors=Dict(0 => (0, 0, 0, 1), 1 => (1, 0, 0, 1)));


p = Path(μm)
sty = launch!(p)
straight!(p, 500μm, sty)
turn!(p, π / 2, 150μm)
straight!(p, 500μm)
launch!(p)
cp = Cell("pathonly", nm)
render!(cp, p, GDSMeta(0))
save("units_pathonly.svg", cp; layercolors=Dict(0 => (0, 0, 0, 1), 1 => (1, 0, 0, 1)));

turnidx = Int((length(p) + 1) / 2) - 1 # the first straight segment of the path
simplify!(p, turnidx .+ (0:2))
attach!(
    p,
    CellReference(cr, Point(0.0μm, 0.0μm)),
    (40μm):(40μm):((pathlength(p[turnidx])) - 40μm),
    i=turnidx
)
c = Cell("decoratedpath", nm)
render!(c, p, GDSMeta(0))
save("units.svg", flatten(c); layercolors=Dict(0 => (0, 0, 0, 1), 1 => (1, 0, 0, 1)));

save("myoutput.gds", c)
save("myoutput.svg", c)
