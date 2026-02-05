#using Pkg
#Pkg.activate("v1.11"; shared=true)
#using FileIO
#using DeviceLayout, DeviceLayout.PreferredUnits, DeviceLayout.SchematicDrivenLayout
#using DeviceLayout.SimpleShapes
#using DeviceLayout.Paths
#import .SchematicDrivenLayout.ExamplePDK
#import .SchematicDrivenLayout.ExamplePDK: LayerVocabulary, ASSEMBLY_TARGET
include("using_Pkg.jl")
# ----------------------- Layers -----------------------
const METAL = LayerVocabulary.METAL_NEGATIVE
const L_FINAL = GDSMeta(1, 0)
const DBG_OUT = GDSMeta(90, 0)
const DBG_IN = GDSMeta(91, 0)
const DBG_TR = GDSMeta(92, 0)

# ======================================================
# 1) 外金属大正方形（仅定义原始几何/钩位；最终金属由布尔结果渲染）
# ======================================================
@compdef struct OuterMetalSquare <: Component
    name = "Outer"
    side = 1000μm
    center = Point(0μm, 0μm)
end

function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, d::OuterMetalSquare)
    p = parameters(d)
    render!(cs, centered(Rectangle(p.side, p.side)), DBG_OUT)  # 调试层
    return cs
end

function SchematicDrivenLayout.hooks(d::OuterMetalSquare)
    p = parameters(d)
    s = p.side / 2
    return (; center=PointHook(p.center, 0°),
        left=PointHook(Point(p.center.x - s, p.center.y), 180°),
        right=PointHook(Point(p.center.x + s, p.center.y), 0°))
end

# ======================================================
# 2) 内部挖空小正方形（仅定义原始几何/钩位；相减在主脚本做）
# ======================================================
@compdef struct InnerVoidSquare <: Component
    name = "Inner"
    length = 1000μm
    width = 500μm
    center = Point(0μm, 0μm)
    angle = 0°
end

function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, d::InnerVoidSquare)
    p = parameters(d)
    render!(cs, centered(Rectangle(p.length, p.width)), DBG_IN)   # 调试层
    return cs
end

function SchematicDrivenLayout.hooks(d::InnerVoidSquare)
    p = parameters(d)
    s = p.length / 2
    return (; center=PointHook(p.center, 0°),
        left=PointHook(Point(p.center.x - s, p.center.y), 0°),
        right=PointHook(Point(p.center.x + s, p.center.y), 0°))
end

# ======================================================
# 3) 金属 trace（横向矩形条；位置用 add_node!/fuse! 来定）
# ======================================================
@compdef struct MetalTraceRect <: Component
    name = "Trace"
    length = 10μm
    width = 1μm
    center = Point(0μm, 0μm)  # 初始在原点；实际位置由 fuse! 决定
    angle = 0°               # 横向
    right_angle = 0°
end

function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, d::MetalTraceRect)
    p = parameters(d)
    render!(cs, centered(Rectangle(p.length, p.width)), DBG_TR) # 调试层
    return cs
end

function SchematicDrivenLayout.hooks(d::MetalTraceRect)
    p = parameters(d)
    return (; center=PointHook(p.center, p.angle),
        left=PointHook(Point(p.center.x - p.length / 2, p.center.y), 180°),
        right=PointHook(Point(p.center.x + p.length / 2, p.center.y), p.right_angle))
end



@compdef struct cps <: Component
    name = "cps"
    style = Paths.Trace(1.0μm)
    # style =Paths.CPW(10.0μm, 6.0μm)
    total_length = 5500μm
    gap = 0.7μm
    length3 = 50μm
    bend_radius = 50μm
    length2 = (total_length - 50μm - length3 - 16 * 3.14159 * bend_radius - 50μm + 2 * bend_radius + gap / 2) / 16#200μm
    length1 = length2 + 50μm
    length4 = length2 / 2 + 50μm - 2 * bend_radius - gap / 2#length1-length2/2-2*bend_radius-gap/2#150μm
    width = 1μm

    tail_length = 200μm

    center = Point(0μm, 0μm)  # 初始在原点；实际位置由 fuse! 决定
    angle0 = 0°
    angle1 = 90°
    angle2 = 180°
    angle3 = -180°
    angle4 = 90°
    angle5 = -90°

    angle_center = 90°
    hook_point2 = -50μm
    hook_point1 = -950μm
    hook_point3 = 650μm
end

function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, d::cps)
    p = parameters(d)
    path = Path(p.center, α0=p.angle1)
    straight!(path, p.length1, p.style)
    turn!(path, p.angle2, p.bend_radius)
    straight!(path, p.length2)
    turn!(path, p.angle3, p.bend_radius)
    straight!(path, p.length2)
    turn!(path, p.angle2, p.bend_radius)
    straight!(path, p.length2)
    turn!(path, p.angle3, p.bend_radius)
    straight!(path, p.length2)
    turn!(path, p.angle2, p.bend_radius)
    straight!(path, p.length2)
    turn!(path, p.angle3, p.bend_radius)
    straight!(path, p.length2)
    turn!(path, p.angle2, p.bend_radius)
    straight!(path, p.length2)
    turn!(path, p.angle3, p.bend_radius)
    straight!(path, p.length2)
    turn!(path, p.angle2, p.bend_radius)
    straight!(path, p.length2)
    turn!(path, p.angle3, p.bend_radius)
    straight!(path, p.length2)
    turn!(path, p.angle2, p.bend_radius)
    straight!(path, p.length2)
    turn!(path, p.angle3, p.bend_radius)
    straight!(path, p.length2)
    turn!(path, p.angle2, p.bend_radius)
    straight!(path, p.length2)

    turn!(path, p.angle3, p.bend_radius)
    straight!(path, p.length2)
    turn!(path, p.angle2, p.bend_radius)
    straight!(path, p.length2 / 2)
    turn!(path, p.angle4, p.bend_radius)
    straight!(path, p.length3)
    turn!(path, p.angle5, p.bend_radius)
    straight!(path, p.length4)



    render!(cs, path, DBG_TR) # 调试层
    return cs
end

function SchematicDrivenLayout.hooks(d::cps)
    p = parameters(d)
    return (; cps_left=PointHook(p.center, p.angle0),
        cps_right=PointHook(Point(p.hook_point1, p.hook_point2), 0°),  ####determine the capacitance position
        cps_center=PointHook(Point(p.hook_point1 / 2 + p.tail_length / 2 - 25μm, p.hook_point3), p.angle_center))
end





###########################


# xy_electrode_line
@compdef struct xy_electrode_line <: Component
    name = "xy_electrode_line"
    taper_len = 50μm    # Taper transition length
    taper_gap = 1μm
    taper_trace = 2μm
    narrow_trace = 10μm
    trace = 6μm     # Trace width
    gap = 4μm     # CPW gap
    bend_radius = 50μm    # Bend radius
    seg_len1 = 100μm   # Straight section length
    seg_len2 = 50μm   # Straight section length
    seg_len3 = 50μm   # Straight section length
    path_point1 = 0μm
    path_point2 = 1μm
    hook_point1 = 0μm            ######- means + y 
    hook_point2 = 1050μm
    α0 = 90°
    α1 = 90°
    α2 = -90°
    α3 = -90°
end



function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, cf::xy_electrode_line)
    params = parameters(cf)

    # 1) Initialize path
    path = Path(Point(params.path_point1, params.path_point2), α0=params.α0)

    # 2) Left port
    sty = launch!(path)

    # 3) First straight segment
    straight!(path, params.seg_len1, sty)

    # 4)  meander
    turn!(path, params.α1, params.bend_radius)
    straight!(path, params.seg_len2, sty)
    # turn!(path, params.α2, params.bend_radius)
    # straight!(path, params.seg_len3, sty)

    # 5) taper

    straight!(path, params.taper_len, Paths.Taper())

    final_cpw = Paths.SimpleCPW(params.taper_trace, params.taper_gap)
    # straight!(path, 0μm, final_cpw)
    # Final short straight segment
    straight!(path, params.narrow_trace, final_cpw)
    # straight!(path, 0μm, Paths.CPW(0μm, params.taper_gap; termination = :open))
    # terminate!(path; gap=params.taper_gap)

    render!(cs, path, GDSMeta(3, 0))


    return cs
end

function SchematicDrivenLayout.hooks(cf::xy_electrode_line)
    params = parameters(cf)
    resonator_hook = PointHook(Point(params.hook_point1, params.hook_point2), params.α3)
    return (; resonator=resonator_hook)
end


















function TransmissionLine(g)
    p_feedline = Path(Point(-1250μm, 0μm) - Point(650μm, 0μm); α0=0°, metadata=LayerVocabulary.METAL_NEGATIVE) # 650μm is the length of the launcher  #-2350 to -1000
    sty = launch!(p_feedline)
    straight!(p_feedline, 2800μm, sty)        #######from 4700 to 2800
    launch!(p_feedline)
    p_feedline_node = add_node!(g, p_feedline)
    return g, p_feedline_node
end









# function OuterMetalSquare(g)
#     OuterMetalSquare1 = OuterMetalSquare(
#         side   = 1000μm
#     )
#     OuterMetalSquare_node = add_node!(g, OuterMetalSquare1)
#     return g, OuterMetalSquare_node
# end


function InnerVoidSquare(g)
    InnerVoidSquare1 = InnerVoidSquare(
        length=1100μm,
        width=1000μm
    )
    InnerVoidSquare2 = InnerVoidSquare(
        length=1100μm,
        width=1000μm
    )
    InnerVoidSquare3 = InnerVoidSquare(
        length=1100μm,
        width=1000μm
    )
    InnerVoidSquare4 = InnerVoidSquare(
        length=1100μm,
        width=1000μm
    )
    InnerVoidSquare1_node = add_node!(g, InnerVoidSquare1)
    InnerVoidSquare2_node = add_node!(g, InnerVoidSquare2)
    InnerVoidSquare3_node = add_node!(g, InnerVoidSquare3)
    InnerVoidSquare4_node = add_node!(g, InnerVoidSquare4)
    return g, InnerVoidSquare1_node, InnerVoidSquare2_node, InnerVoidSquare3_node, InnerVoidSquare4_node
end


function MetalTraceRect(g)
    MetalTraceRect1_1 = MetalTraceRect(
        length=125μm,
        width=1μm,
        center=Point(0μm, 0μm),
        angle=0°
    )
    MetalTraceRect1_2 = MetalTraceRect(
        length=125μm,
        width=1μm,
        center=Point(0μm, 0μm),
        angle=0°
    )
    MetalTraceRect1_3 = MetalTraceRect(
        length=125μm,
        width=1μm,
        center=Point(0μm, 0μm),
        angle=0°
    )
    MetalTraceRect1_4 = MetalTraceRect(
        length=125μm,
        width=1μm,
        center=Point(0μm, 0μm),
        angle=0°
    )


    MetalTraceRect1_1_node = add_node!(g, MetalTraceRect1_1)
    MetalTraceRect1_2_node = add_node!(g, MetalTraceRect1_2)
    MetalTraceRect1_3_node = add_node!(g, MetalTraceRect1_3)
    MetalTraceRect1_4_node = add_node!(g, MetalTraceRect1_4)
    return g, MetalTraceRect1_1_node, MetalTraceRect1_2_node, MetalTraceRect1_3_node, MetalTraceRect1_4_node
end


#### for the coupling capacitance
function MetalTraceRect2(g)
    MetalTraceRect2_1 = MetalTraceRect(
        length=5μm,
        width=1μm,
        center=Point(0μm, 0μm),
        angle=0°
    )

    MetalTraceRect2_2 = MetalTraceRect(
        length=5μm,
        width=1μm,
        center=Point(0μm, 0μm),
        angle=0°
    )

    MetalTraceRect2_3 = MetalTraceRect(
        length=5μm,
        width=1μm,
        center=Point(0μm, 0μm),
        angle=0°
    )

    MetalTraceRect2_4 = MetalTraceRect(
        length=5μm,
        width=1μm,
        center=Point(0μm, 0μm),
        angle=0°
    )

    MetalTraceRect2_1_node = add_node!(g, MetalTraceRect2_1)
    MetalTraceRect2_2_node = add_node!(g, MetalTraceRect2_2)
    MetalTraceRect2_3_node = add_node!(g, MetalTraceRect2_3)
    MetalTraceRect2_4_node = add_node!(g, MetalTraceRect2_4)
    return g, MetalTraceRect2_1_node, MetalTraceRect2_2_node, MetalTraceRect2_3_node, MetalTraceRect2_4_node
end

#### for the coupling capacitance(PARALLEL)
function MetalTraceRect3(g)
    MetalTraceRect3_1 = MetalTraceRect(
        length=50μm,
        width=10μm,
        center=Point(0μm, 0μm),
        angle=0°
    )
    MetalTraceRect3_2 = MetalTraceRect(
        length=50μm,
        width=10μm,
        center=Point(0μm, 0μm),
        angle=0°
    )
    MetalTraceRect3_3 = MetalTraceRect(
        length=50μm,
        width=10μm,
        center=Point(0μm, 0μm),
        angle=0°
    )

    MetalTraceRect3_4 = MetalTraceRect(
        length=50μm,
        width=10μm,
        center=Point(0μm, 0μm),
        angle=0°
    )



    MetalTraceRect3_1_node = add_node!(g, MetalTraceRect3_1)
    MetalTraceRect3_2_node = add_node!(g, MetalTraceRect3_2)
    MetalTraceRect3_3_node = add_node!(g, MetalTraceRect3_3)
    MetalTraceRect3_4_node = add_node!(g, MetalTraceRect3_4)
    return g, MetalTraceRect3_1_node, MetalTraceRect3_2_node, MetalTraceRect3_3_node, MetalTraceRect3_4_node
end

function MetalTraceRect4(g)
    MetalTraceRect4_1 = MetalTraceRect(
        length=120μm,
        width=1μm,
        center=Point(0μm, 0μm),
        angle=180°,
        right_angle=180°
    )
    MetalTraceRect4_2 = MetalTraceRect(
        length=120μm,
        width=1μm,
        center=Point(0μm, 0μm),
        angle=180°,
        right_angle=180°
    )
    MetalTraceRect4_3 = MetalTraceRect(
        length=120μm,
        width=1μm,
        center=Point(0μm, 0μm),
        angle=180°,
        right_angle=180°
    )

    MetalTraceRect4_4 = MetalTraceRect(
        length=120μm,
        width=1μm,
        center=Point(0μm, 0μm),
        angle=180°,
        right_angle=180°
    )



    MetalTraceRect4_1_node = add_node!(g, MetalTraceRect4_1)
    MetalTraceRect4_2_node = add_node!(g, MetalTraceRect4_2)
    MetalTraceRect4_3_node = add_node!(g, MetalTraceRect4_3)
    MetalTraceRect4_4_node = add_node!(g, MetalTraceRect4_4)
    return g, MetalTraceRect4_1_node, MetalTraceRect4_2_node, MetalTraceRect4_3_node, MetalTraceRect4_4_node
end





function cps1(g)
    cps1_1 = cps(
        name="cps1_1",
        total_length=5500μm,
        # length1 = 331μm,
        # length2 = 256μm,
        length3=50μm,
        # length4 = 152.65μm,
        width=1μm,
        bend_radius=25μm,###50
        center=Point(0μm, 0μm),
        angle0=0°,
        angle1=90°,
        angle2=180°,
        angle3=-180°,
        angle4=-90°,
        angle5=90°,
        angle_center=90°,
        hook_point2=50μm,
        hook_point1=-850μm,
        hook_point3=1400μm
    )
    cps1_2 = cps(
        name="cps1_2",
        # length1 = 331+16.13μm,
        # length2 = 256+16.13μm,
        # length3 = 50μm,
        # length4 = 149.65μm,
        total_length=5750μm,
        # length1 = 331μm,
        # length2 = 256μm,
        length3=50μm,
        # length4 = 152.65μm,
        width=1μm,
        bend_radius=25μm,
        center=Point(0μm, 0μm),
        angle0=0°,
        angle1=90°,
        angle2=180°,
        angle3=-180°,
        angle4=-90°,
        angle5=90°,
        angle_center=90°,
        hook_point2=50μm,
        hook_point1=-850μm,
        hook_point3=-1200μm
    )
    cps1_3 = cps(
        name="cps1",
        total_length=6000μm,
        # length1 = 325μm,
        # length2 = 250μm,
        length3=50μm,
        # length4 = 149.65μm,
        width=1μm,
        bend_radius=25μm,
        center=Point(0μm, 0μm),
        angle0=0°,
        angle1=90°,
        angle2=180°,
        angle3=-180°,
        angle4=-90°,
        angle5=90°,
        angle_center=90°,
        hook_point2=50μm,
        hook_point1=-850μm,
        hook_point3=-1000μm
    )
    cps1_4 = cps(
        name="cps1",
        total_length=6250μm,
        # length1 = 325μm,
        # length2 = 250μm,
        length3=50μm,
        # length4 = 149.65μm,
        width=1μm,
        bend_radius=25μm,
        center=Point(0μm, 0μm),
        angle0=0°,
        angle1=90°,
        angle2=180°,
        angle3=-180°,
        angle4=-90°,
        angle5=90°,
        hook_point2=50μm,
        hook_point1=-850μm,
        hook_point3=800μm
    )
    cps1_1_node = add_node!(g, cps1_1)
    cps1_2_node = add_node!(g, cps1_2)
    cps1_3_node = add_node!(g, cps1_3)
    cps1_4_node = add_node!(g, cps1_4)
    return g, cps1_1_node, cps1_2_node, cps1_3_node, cps1_4_node
end

function cps2(g)
    cps2_1 = cps(
        name="cps2_1",
        total_length=5500μm,
        # length1 = 331μm,
        # length2 = 256μm,
        length3=50μm,
        # length4 = 152.65μm,
        width=1μm,
        bend_radius=25μm,
        center=Point(0μm, 0μm),
        angle0=0°,
        angle1=-90°,
        angle2=-180°,
        angle3=180°,
        angle4=90°,
        angle5=-90°,
        hook_point2=-50μm,
        hook_point1=-850μm
    )
    cps2_2 = cps(
        name="cps2_2",
        total_length=5750μm,
        # length1 = 331+16.13μm,
        # length2 = 256+16.13μm,
        length3=50μm,
        # length4 = 149.65μm,
        width=1μm,
        bend_radius=25μm,
        center=Point(0μm, 0μm),
        angle0=0°,
        angle1=-90°,
        angle2=-180°,
        angle3=180°,
        angle4=90°,
        angle5=-90°,
        hook_point2=-50μm,
        hook_point1=-850μm
    )
    cps2_3 = cps(
        name="cps2",
        total_length=6000μm,
        # length1 = 325μm,
        # length2 = 250μm,
        length3=50μm,
        # length4 = 149.65μm,
        width=1μm,
        bend_radius=25μm,
        center=Point(0μm, 0μm),
        angle0=0°,
        angle1=-90°,
        angle2=-180°,
        angle3=180°,
        angle4=90°,
        angle5=-90°,
        hook_point2=-50μm,
        hook_point1=-850μm
    )
    cps2_4 = cps(
        name="cps2",
        total_length=6250μm,
        # length1 = 325μm,
        # length2 = 250μm,
        length3=50μm,
        # length4 = 149.65μm,
        width=1μm,
        bend_radius=25μm,
        center=Point(0μm, 0μm),
        angle0=0°,
        angle1=-90°,
        angle2=-180°,
        angle3=180°,
        angle4=90°,
        angle5=-90°,
        hook_point2=-50μm,
        hook_point1=-850μm
    )
    cps2_1_node = add_node!(g, cps2_1)
    cps2_2_node = add_node!(g, cps2_2)
    cps2_3_node = add_node!(g, cps2_3)
    cps2_4_node = add_node!(g, cps2_4)
    return g, cps2_1_node, cps2_2_node, cps2_3_node, cps2_4_node
end

##################################






function xy_electrode_line(g)
    p_xy_electrode_line1 = xy_electrode_line(taper_len=30μm,    # Taper transition length
        taper_gap=1μm,
        taper_trace=1μm,
        trace=6μm,    # Trace width
        gap=4μm,    # CPW gap
        bend_radius=50μm,   # Bend radius
        seg_len1=250μm,  # Straight section length
        seg_len2=500μm,   # Straight section length
        seg_len3=50μm,  # Straight section length
        narrow_trace=10μm,
        path_point1=0μm,
        path_point2=0μm,
        hook_point1=-700μm - 250μm + 150μm,    ######y -seg_len1
        hook_point2=-(500μm + 50μm + 10μm + 30μm),   #####x seg_len2+taper_len+narrow_trace
        α0=-180°,
        α1=90°,
        α2=-90°,
        α3=-90°
    )

    p_xy_electrode_line2 = xy_electrode_line(   ###########leftbelow
        taper_len=30μm,    # Taper transition length
        taper_gap=1μm,
        taper_trace=1μm,
        trace=6μm,    # Trace width
        gap=4μm,    # CPW gap
        bend_radius=50μm,   # Bend radius
        seg_len1=250μm,  # Straight section length
        seg_len2=500μm,   # Straight section length
        seg_len3=50μm,  # Straight section length
        narrow_trace=10μm,
        path_point1=0μm,
        path_point2=0μm,
        hook_point1=-700μm - 250μm + 150μm,
        hook_point2=-(500μm + 50μm + 10μm + 30μm),
        α0=180°,
        α1=90°,
        α2=90°,
        α3=-90°
    )

    p_xy_electrode_line3 = xy_electrode_line(taper_len=30μm,    # Taper transition length
        taper_gap=1μm,
        taper_trace=1μm,
        trace=6μm,    # Trace width
        gap=4μm,    # CPW gap
        bend_radius=50μm,   # Bend radius
        seg_len1=250μm,  # Straight section length
        seg_len2=500μm,   # Straight section length
        seg_len3=50μm,  # Straight section length
        narrow_trace=10μm,
        path_point1=0μm,
        path_point2=0μm,
        hook_point1=-700μm - 250μm + 150μm,
        hook_point2=-(500μm + 50μm + 10μm + 30μm),
        α0=180°,
        α1=90°,
        α2=90°,
        α3=-90°
    )

    p_xy_electrode_line4 = xy_electrode_line(taper_len=30μm,    # Taper transition length
        taper_gap=1μm,
        taper_trace=1μm,
        trace=6μm,    # Trace width
        gap=4μm,    # CPW gap
        bend_radius=50μm,   # Bend radius
        seg_len1=250μm,  # Straight section length
        seg_len2=500μm,   # Straight section length
        seg_len3=50μm,  # Straight section length
        narrow_trace=10μm,
        path_point1=0μm,
        path_point2=0μm,
        hook_point1=-700μm - 250μm + 150μm,
        hook_point2=(500μm + 50μm + 10μm + 30μm),
        α0=180°,
        α1=-90°,
        α2=-90°,
        α3=90°
    )
    p_xye_node1 = add_node!(g, p_xy_electrode_line1)
    p_xye_node2 = add_node!(g, p_xy_electrode_line2)
    p_xye_node3 = add_node!(g, p_xy_electrode_line3)
    p_xye_node4 = add_node!(g, p_xy_electrode_line4)

    return g, p_xye_node1, p_xye_node2, p_xye_node3, p_xye_node4
end







function assemble_schematic_graph()
    g = SchematicGraph("simplechip")

    # g, OuterMetalSquare_node = OuterMetalSquare(g)
    g, p_feedline_node = TransmissionLine(g)
    g, InnerVoidSquare1_node, InnerVoidSquare2_node, InnerVoidSquare3_node, InnerVoidSquare4_node = InnerVoidSquare(g)
    g, MetalTraceRect1_1_node, MetalTraceRect1_2_node, MetalTraceRect1_3_node, MetalTraceRect1_4_node = MetalTraceRect(g)
    # g, MetalTraceRect2_1_node,MetalTraceRect2_2_node,MetalTraceRect2_3_node,MetalTraceRect2_4_node=MetalTraceRect2(g)
    # g, MetalTraceRect3_1_node,MetalTraceRect3_2_node,MetalTraceRect3_3_node,MetalTraceRect3_4_node=MetalTraceRect3(g)
    g, MetalTraceRect4_2_node, MetalTraceRect4_3_node, MetalTraceRect4_4_node = MetalTraceRect4(g)
    g, cps1_1_node, cps1_2_node, cps1_3_node, cps1_4_node = cps1(g)
    g, cps2_1_node, cps2_2_node, cps2_3_node, cps2_4_node = cps2(g)
    g, p_xye_node1, p_xye_node2, p_xye_node3, p_xye_node4 = xy_electrode_line(g)



    #     g, p_feedline_node = TransmissionLine(g)
    # g, InnerVoidSquare1_node,InnerVoidSquare2_node,InnerVoidSquare3_node,InnerVoidSquare4_node = InnerVoidSquare(g)
    # g, MetalTraceRect1_1_node,MetalTraceRect1_2_node,MetalTraceRect1_3_node,MetalTraceRect1_4_node=MetalTraceRect(g)
    # g, MetalTraceRect2_1_node,MetalTraceRect2_2_node,MetalTraceRect2_3_node,MetalTraceRect2_4_node=MetalTraceRect2(g)
    # g, MetalTraceRect3_node=MetalTraceRect3(g)
    # g, cps1_node=cps1(g)
    # g, cps2_node=cps2(g)


    attach!(g, p_feedline_node, cps1_1_node => :cps_center, 0.85mm, i=4, location=-1)
    # fuse!(g, OuterMetalSquare_node => :center, InnerVoidSquare1_node => :center)
    fuse!(g, InnerVoidSquare1_node => :left, MetalTraceRect1_1_node => :left)
    fuse!(g, MetalTraceRect1_1_node => :right, cps1_1_node => :cps_left)
    fuse!(g, MetalTraceRect1_1_node => :right, cps2_1_node => :cps_left)
    # fuse!(g, MetalTraceRect2_1_node => :center, cps2_1_node => :cps_right)
    # fuse!(g, MetalTraceRect3_1_node => :center, cps1_1_node => :cps_right)
    # fuse!(g, MetalTraceRect4_1_node => :right, InnerVoidSquare1_node => :right)
    fuse!(g, p_xye_node1 => :resonator, InnerVoidSquare1_node => :right)



    attach!(g, p_feedline_node, cps1_2_node => :cps_center, 1.95mm, i=4, location=1)
    # fuse!(g, OuterMetalSquare_node => :center, InnerVoidSquare1_node => :center)
    fuse!(g, InnerVoidSquare2_node => :left, MetalTraceRect1_2_node => :left)
    fuse!(g, MetalTraceRect1_2_node => :right, cps1_2_node => :cps_left)
    fuse!(g, MetalTraceRect1_2_node => :right, cps2_2_node => :cps_left)
    # fuse!(g, MetalTraceRect2_2_node => :center, cps2_2_node => :cps_right)
    # fuse!(g, MetalTraceRect3_2_node => :center, cps1_2_node => :cps_right)
    fuse!(g, MetalTraceRect4_2_node => :right, InnerVoidSquare2_node => :right)
    fuse!(g, p_xye_node2 => :resonator, InnerVoidSquare2_node => :right)


    attach!(g, p_feedline_node, cps1_3_node => :cps_center, 0.85mm, i=4, location=-1)
    # fuse!(g, OuterMetalSquare_node => :center, InnerVoidSquare1_node => :center)
    fuse!(g, InnerVoidSquare3_node => :left, MetalTraceRect1_3_node => :left)
    fuse!(g, MetalTraceRect1_3_node => :right, cps1_3_node => :cps_left)
    fuse!(g, MetalTraceRect1_3_node => :right, cps2_3_node => :cps_left)
    # fuse!(g, MetalTraceRect2_3_node => :center, cps2_3_node => :cps_right)
    # fuse!(g, MetalTraceRect3_3_node => :center, cps1_3_node => :cps_right)
    fuse!(g, MetalTraceRect4_3_node => :right, InnerVoidSquare3_node => :right)
    fuse!(g, p_xye_node3 => :resonator, InnerVoidSquare3_node => :right)



    attach!(g, p_feedline_node, cps1_4_node => :cps_center, 1.95mm, i=4, location=1)
    # fuse!(g, OuterMetalSquare_node => :center, InnerVoidSquare1_node => :center)
    fuse!(g, InnerVoidSquare4_node => :left, MetalTraceRect1_4_node => :left)
    fuse!(g, MetalTraceRect1_4_node => :right, cps1_4_node => :cps_left)
    fuse!(g, MetalTraceRect1_4_node => :right, cps2_4_node => :cps_left)
    # fuse!(g, MetalTraceRect2_4_node => :center, cps2_4_node => :cps_right)
    # fuse!(g, MetalTraceRect3_4_node => :center, cps1_4_node => :cps_right)
    fuse!(g, MetalTraceRect4_4_node => :right, InnerVoidSquare4_node => :right)
    fuse!(g, p_xye_node4 => :resonator, InnerVoidSquare4_node => :right)




    return g
end





# using DeviceLayout.Polygons: union2d, difference2d

# """
# 把 cell 里若干层做布尔：
#  positives 里的层先做并集；
#  negatives 里的层做并集；
#  最后 result = positives_union  negatives_union，
#  并把结果渲染到 out_meta（例如 METAL）。
#  同时可选清理掉参与布尔的中间层。
# """
# function boolean_into!(cell::Cell;
#     positives::Vector{GDSMeta},
#     negatives::Vector{GDSMeta}=GDSMeta[],
#     out_meta::GDSMeta,
#     drop_sources::Bool=true,
# )
#     # 1) 把某些 meta 的多边形收集出来
#     function polys_on(cell, metas::Vector{GDSMeta})
#         out = Polygon[]
#         for pr in cell.polys
#             if pr.meta in metas
#                 # pr.poly 可能已经是 Polygon/PolygonSet，统一成 Polygon
#                 if pr.poly isa Polygon
#                     push!(out, pr.poly)
#                 elseif pr.poly isa Vector{Polygon}
#                     append!(out, pr.poly)
#                 else
#                     # 兼容不同版本：如果是 PolygonSet/Renderable，可尝试转换
#                     append!(out, collect(pr.poly))
#                 end
#             end
#         end
#         return out
#     end

#     pos_polys = polys_on(cell, positives)
#     neg_polys = polys_on(cell, negatives)

#     # 2) 各自并集
#     pos_union = isempty(pos_polys) ? Polygon[] : reduce((a,b)->union2d(a,b), pos_polys)
#     neg_union = isempty(neg_polys) ? Polygon[] : reduce((a,b)->union2d(a,b), neg_polys)

#     # 3) 相减：金属 = 正并集 \ 负并集
#     metal_polys =
#         isempty(neg_union) ? pos_union : difference2d(pos_union, neg_union)

#     # 4) 可选：清理掉参与布尔的源层（避免把中间层也导出）
#     if drop_sources
#         filter!(pr -> !(pr.meta in positives) && !(pr.meta in negatives), cell.polys)
#     end

#     # 5) 把结果写到目标金属层
#     render!(cell, metal_polys, out_meta)

#     return cell
# end









g = assemble_schematic_graph()

@time "Floorplanning" floorplan = plan(g)
# Chip
center_xyz = DeviceLayout.center(floorplan)
chip = centered(Rectangle(5mm, 5mm), on_pt=Point(0mm, 0mm))   #### from 7 to 5
# Define rectangle that gets extruded to generate substrate volume
render!(floorplan.coordinate_system, chip, LayerVocabulary.CHIP_AREA)

check!(floorplan)

unit_chip = Cell("unit_chip") # "unit_chip" = "pattern used for fabrication"
@time "Rendering to polygons" render!(unit_chip, floorplan, ASSEMBLY_TARGET)
#render!(g, identity, strict=:no, simulation=true)
flatten!(unit_chip)




# boolean_into!(unit_chip;
#     positives = [DBG_TR, DBG_OUT],
#     negatives = [DBG_IN],
#     out_meta  = L_FINAL,
#     drop_sources = true
# )



# 对 unit_chip 上的若干层做布尔：把 DBG_TR 与 DBG_OUT 合并后减去 DBG_IN
metal = difference2d(
    unit_chip => [DBG_IN],
    unit_chip => [DBG_TR],)

# 把布尔结果渲染到最终金属层（GDSMeta）
render!(unit_chip, metal, L_FINAL)



# Assemble into a larger 2x2 sample
full_chip = Cell("full_chip")
push!(full_chip.refs, CellArray(unit_chip, Point(0μm, 0μm), dr=Point(0mm, -5.24mm), dc=Point(5.24mm, 0mm), nr=2, nc=2))         ######from  7 to 5
flatten!(full_chip)

# add chip markups
chip_markings = Cell(uniquename("chip_markup"))
PolyText.polytext!(chip_markings, "CQED Lab @ UW\nSlime Sr v3.1\nTa/Nb S1", DotMatrix(; pixelsize=9μm, rounding=3μm))         #########from v1 to v3
push!(full_chip.refs, CellReference(chip_markings, Point(-2.2mm, -1.99mm)))

chip_markings = Cell(uniquename("chip_markup"))
PolyText.polytext!(chip_markings, "CQED Lab @ UW\nSlime Sr v3.1\nTa/Nb S2", DotMatrix(; pixelsize=9μm, rounding=3μm))  #####from 16 to 12,6 to 4
push!(full_chip.refs, CellReference(chip_markings, Point(2.99mm, -1.99mm)))          ######### left corner

chip_markings = Cell(uniquename("chip_markup"))
PolyText.polytext!(chip_markings, "CQED Lab @ UW\nSlime Sr v3.1\nTa/Nb S3", DotMatrix(; pixelsize=9μm, rounding=3μm))
push!(full_chip.refs, CellReference(chip_markings, Point(-2.2mm, -7.19mm)))

chip_markings = Cell(uniquename("chip_markup"))
PolyText.polytext!(chip_markings, "CQED Lab @ UW\nSlime Sr v3.1\nTa/Nb S4", DotMatrix(; pixelsize=9μm, rounding=3μm))
push!(full_chip.refs, CellReference(chip_markings, Point(2.99mm, -7.199mm)))

# add dicing cross
dicing_marker = Cell(uniquename("dicing_marker"))
render!(dicing_marker, centered(Rectangle(1mm, 0.1mm)))
render!(dicing_marker, centered(Rectangle(0.1mm, 1mm)))
push!(full_chip.refs, CellArray(dicing_marker, Point(-2.62mm, 2.62mm), dr=Point(0mm, -5.23mm), dc=Point(5.23mm, 0mm), nr=3, nc=3))         ############from 3.5 to 2.5 7 to5

flatten!(full_chip)

save("dmrv1.gds", full_chip)





















