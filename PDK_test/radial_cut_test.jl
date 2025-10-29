using Pkg
Pkg.activate(".")  # ensures the environment is used
using FileIO
using DeviceLayout, DeviceLayout.PreferredUnits, DeviceLayout.SchematicDrivenLayout, DeviceLayout.SimpleShapes
import DeviceLayout: μm, nm

c = Cell("main", nm)
r = 20μm
Θ = π / 3
h = 0μm
narc = 100
p = Path(Point(h * tan(Θ / 2), -h), α0=(Θ - π) / 2)
straight!(p, r - h * sec(Θ / 2), Paths.Trace(2μm)) # Trace should be r
turn!(p, -π / 2, zero(h))
turn!(p, -Θ, r)
turn!(p, -π / 2, zero(h))
straight!(p, r - h * sec(Θ / 2))

seg = segment(p[3])
pts = map(seg, range(pathlength(seg), stop=zero(h), length=narc))

push!(pts, Paths.p1(p))
h != zero(h) && push!(pts, Paths.p0(p))
poly = Polygon(pts) + Point(zero(h), h) # + Point(0.0, (r-h)/2)
#poly = Polygon(pts)
place!(c, poly)
render!(c, poly, GDSMeta(1))
save("radial_cut.svg", flatten(c));