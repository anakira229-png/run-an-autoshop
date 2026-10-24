# Builds the RunAutoshop_Pack1 scene (Sedan v3 + parts kit) in Blender. Run it from Blender's Text Editor
# (written without callbacks so it also passes the MCP add-on's safe mode).
# Units are studs. Cars face -Y in Blender (Blender's front view); exported with forward -Z / up Y and
# Apply Transform, Roblox's Import 3D brings that in facing -Z. Car left (Roblox -X) is Blender +X.
# Every exported mesh is named <Model>__<Part>; helper objects start with "_".
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

SCENE_NAME = "RunAutoshop_Pack1"
I4 = Matrix.Identity(4)


def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def sock(node, ident):
    for s in node.inputs:
        if s.identifier == ident:
            return s
    return None


def material(name, rgb, rough=0.5, metal=0.0, emit=0.0, alpha=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    if m.node_tree is None:
        m.use_nodes = True
    bsdf = None
    for n in m.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            bsdf = n
    col = (srgb(rgb[0]), srgb(rgb[1]), srgb(rgb[2]))
    sock(bsdf, "Base Color").default_value = (col[0], col[1], col[2], 1.0)
    sock(bsdf, "Roughness").default_value = rough
    sock(bsdf, "Metallic").default_value = metal
    sock(bsdf, "Emission Color").default_value = (col[0], col[1], col[2], 1.0)
    sock(bsdf, "Emission Strength").default_value = emit
    sock(bsdf, "Alpha").default_value = alpha
    if alpha < 1:
        m.surface_render_method = "BLENDED"
    m.diffuse_color = (col[0], col[1], col[2], alpha)
    return m


MAT = {
    "paint": material("RA_Paint", (70, 110, 170), 0.35),
    "trim": material("RA_Trim", (40, 40, 45), 0.6),
    "rubber": material("RA_Rubber", (28, 28, 30), 0.85),
    "chrome": material("RA_Chrome", (205, 205, 212), 0.25, 1.0),
    "metal": material("RA_Metal", (95, 100, 110), 0.45, 0.8),
    "darkmetal": material("RA_DarkMetal", (60, 58, 56), 0.55, 0.7),
    "glass": material("RA_Glass", (40, 55, 70), 0.05, 0.0, 0.0, 0.55),
    "head": material("RA_Headlight", (255, 245, 210), 0.2, 0.0, 2.0),
    "tail": material("RA_Taillight", (200, 20, 20), 0.2, 0.0, 2.0),
    "interior": material("RA_Interior", (55, 55, 60), 0.9),
    "fabric": material("RA_Fabric", (140, 30, 30), 0.9),
    "accent": material("RA_Accent", (200, 50, 40), 0.4),
    "yellow": material("RA_Yellow", (240, 190, 40), 0.4),
    "white": material("RA_White", (235, 235, 230), 0.5),
    "battery": material("RA_Battery", (30, 30, 35), 0.6),
    "red": material("RA_Red", (200, 30, 30), 0.4),
}

SC = bpy.data.scenes.get(SCENE_NAME) or bpy.data.scenes.new(SCENE_NAME)
for _o in list(SC.collection.all_objects):
    bpy.data.objects.remove(_o, do_unlink=True)
SC.unit_settings.system = "METRIC"
SC.unit_settings.scale_length = 1.0
bpy.context.window_manager.windows[0].scene = SC


def bake(ob):
    dg = SC.view_layers[0].depsgraph
    dg.update()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    me.name = ob.name
    return ob


def obj(name, bm, mat=None, bevel=0.0, segs=3, angle=30):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    SC.collection.objects.link(ob)
    if mat is not None:
        me.materials.append(mat)
    if bevel:
        m = ob.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = segs
        m.limit_method = "ANGLE"
        m.angle_limit = math.radians(angle)
        m.use_clamp_overlap = True
        bake(ob)
    return ob


def cut(target, cutters):
    for c in cutters:
        m = target.modifiers.new("Bool", "BOOLEAN")
        m.object = c
        m.operation = "DIFFERENCE"
        m.solver = "EXACT"
    bake(target)
    for c in cutters:
        bpy.data.objects.remove(c, do_unlink=True)
    return target


def cube(bm, size, center, M=None):
    m = (M or I4) @ Matrix.LocRotScale(Vector(center), None, Vector(size))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


AXIS_ROT = {
    "X": Matrix.Rotation(math.pi / 2, 4, "Y"),
    "Y": Matrix.Rotation(-math.pi / 2, 4, "X"),
    "Z": I4,
}


def cyl(bm, r, depth, center, axis="Z", segs=24, r2=None, M=None):
    # Radius r at the axis' negative end, r2 at its positive end.
    m = (M or I4) @ Matrix.Translation(Vector(center)) @ AXIS_ROT[axis]
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=depth, matrix=m
    )


def axis_point(axis, u, v, w):
    if axis == "X":
        return (w, u, v)
    if axis == "Y":
        return (u, w, v)
    return (u, v, w)


def prism(bm, pts, a0, a1, axis="X"):
    lo = [bm.verts.new(axis_point(axis, p[0], p[1], a0)) for p in pts]
    hi = [bm.verts.new(axis_point(axis, p[0], p[1], a1)) for p in pts]
    bm.faces.new(lo)
    bm.faces.new(hi)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def loft(bm, bot, top):
    # bot/top: (half_x, y0, y1, z)
    rings = []
    for hx, y0, y1, z in (bot, top):
        rings.append([bm.verts.new(p) for p in ((-hx, y0, z), (hx, y0, z), (hx, y1, z), (-hx, y1, z))])
    b, t = rings
    bm.faces.new(b)
    bm.faces.new(t)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((b[i], b[j], t[j], t[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def revolve(bm, prof, center, axis="X", segs=32, start=0.0, sweep=2 * math.pi, lugs=False):
    # prof: closed loop of (a, r); a runs along the axis. Builds in a scratch bmesh, then merges into bm.
    sub = bmesh.new()
    cx, cy, cz = center
    full = abs(sweep - 2 * math.pi) < 1e-6
    n_ang = segs if full else segs + 1
    rings = []
    for i in range(n_ang):
        th = start + sweep * i / segs
        ring = []
        for a, r in prof:
            if lugs and i % 2 == 1 and r > 1.33 and 0.25 < abs(a) < 0.57:
                r = r + 0.03
            c, s = math.cos(th) * r, math.sin(th) * r
            if axis == "X":
                p = (cx + a, cy + c, cz + s)
            elif axis == "Y":
                p = (cx + c, cy + a, cz + s)
            else:
                p = (cx + c, cy + s, cz + a)
            ring.append(sub.verts.new(p))
        rings.append(ring)
    n = len(prof)
    for i in range(segs):
        A = rings[i]
        B = rings[(i + 1) % n_ang] if full else rings[i + 1]
        for j in range(n):
            k = (j + 1) % n
            sub.faces.new((A[j], A[k], B[k], B[j]))
    if not full:
        sub.faces.new(rings[0])
        sub.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(sub, faces=sub.faces)
    merge(bm, sub)


def merge(bm, sub, M=None):
    tmp = bpy.data.meshes.new("_tmp")
    sub.to_mesh(tmp)
    sub.free()
    if M is not None:
        tmp.transform(M)
    bm.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)


def bevel_except_z(bm, offset, segs, z):
    # Bevels every edge except the ones lying in the plane at height z.
    edges = [e for e in bm.edges if not (abs(e.verts[0].co.z - z) < 1e-4 and abs(e.verts[1].co.z - z) < 1e-4)]
    bmesh.ops.bevel(bm, geom=edges, offset=offset, segments=segs, profile=0.5, affect="EDGES", clamp_overlap=True)


def inset_poly(pts, d):
    n = len(pts)
    lines = []
    for i in range(n):
        p = Vector(pts[i])
        e = (Vector(pts[(i + 1) % n]) - p).normalized()
        lines.append((p + Vector((-e.y, e.x)) * d, e))
    out = []
    for i in range(n):
        p1, e1 = lines[i - 1]
        p2, e2 = lines[i]
        cross = e1.x * e2.y - e1.y * e2.x
        t = ((p2.x - p1.x) * e2.y - (p2.y - p1.y) * e2.x) / cross
        q = p1 + e1 * t
        out.append((q.x, q.y))
    return out


def clip(pts, k, c, keep_less):
    out = []
    n = len(pts)
    for i in range(n):
        A, B = pts[i], pts[(i + 1) % n]
        ina = A[k] <= c if keep_less else A[k] >= c
        inb = B[k] <= c if keep_less else B[k] >= c
        if ina:
            out.append(A)
        if ina != inb:
            t = (c - A[k]) / (B[k] - A[k])
            out.append((A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t))
    return out


# ---------------------------------------------------------------- shared part geometry

TIRE_R = 1.34


def tire_geo(bm, c):
    # Encloses the BuildAssets physics cylinder (1.2 wide, radius 1.3): r >= 1.31 wherever |x| <= 0.6.
    right = [
        (0.08, 1.34), (0.10, 1.32), (0.16, 1.32), (0.18, 1.34), (0.30, 1.34), (0.56, 1.34), (0.60, 1.315),
        (0.615, 1.29), (0.62, 1.2), (0.62, 0.96), (0.58, 0.88), (0.50, 0.86),
    ]
    left = [(-a, r) for a, r in reversed(right)]
    revolve(bm, right + left, c, "X", segs=40, lugs=True)


def hub_geo(bm, c):
    cx, cy, cz = c
    T = Matrix.Translation(Vector(c))
    for s in (1, -1):
        lip = [(0.56, 0.76), (0.64, 0.76), (0.665, 0.80), (0.665, 0.86), (0.63, 0.905), (0.56, 0.905)]
        if s < 0:
            lip = [(-a, r) for a, r in reversed(lip)]
        revolve(bm, lip, c, "X", segs=32)
        cyl(bm, 0.55, 0.05, (cx + s * 0.605, cy, cz), "X", 24)
        if s > 0:
            cyl(bm, 0.2, 0.1, (cx + 0.68, cy, cz), "X", 16, 0.13)
        else:
            cyl(bm, 0.13, 0.1, (cx - 0.68, cy, cz), "X", 16, 0.2)
        for k in range(5):
            phi = math.radians(36 + 72 * k)
            cube(bm, (0.07, 0.2, 0.32), (s * 0.615, 0, 0.62), T @ Matrix.Rotation(phi, 4, "X"))


def engine_geo(bm, M):
    # Envelope 2.6 x 2.4 x 1.4 (x, y, z) centered at the origin, front at -Y.
    cube(bm, (1.4, 1.7, 0.4), (0, 0.1, -0.5), M)
    cube(bm, (2.0, 2.2, 0.8), (0, 0, 0.0), M)
    cube(bm, (1.7, 2.0, 0.3), (0, 0, 0.55), M)
    for s in (1, -1):
        cube(bm, (0.3, 0.5, 0.3), (s * 1.15, -0.2, -0.1), M)
    cube(bm, (1.6, 0.2, 0.9), (0, -1.1, 0.05), M)
    cube(bm, (2.0, 0.2, 1.1), (0, 1.1, -0.05), M)


def valve_cover_geo(bm, M):
    cube(bm, (1.5, 1.8, 0.22), (0, 0, 0.81), M)
    for k in range(4):
        cube(bm, (0.7, 0.09, 0.08), (-0.2, -0.6 + k * 0.4, 0.94), M)


def intake_geo(bm, M):
    cyl(bm, 0.2, 1.7, (0.95, 0, 0.78), "Y", 16, M=M)
    for k in range(4):
        cube(bm, (0.42, 0.2, 0.16), (0.75, -0.6 + k * 0.4, 0.62), M)


def exhaust_geo(bm, M):
    for k in range(4):
        cube(bm, (0.22, 0.2, 0.45), (-1.1, -0.6 + k * 0.4, 0.18), M)
    cyl(bm, 0.15, 1.8, (-1.2, 0.05, -0.12), "Y", 12, M=M)


def pulley_geo(bm, M):
    cyl(bm, 0.32, 0.14, (0, -1.27, -0.25), "Y", 20, M=M)
    cyl(bm, 0.22, 0.14, (0, -1.27, 0.3), "Y", 20, M=M)
    cyl(bm, 0.2, 0.45, (0.72, -1.05, 0.35), "Y", 16, M=M)
    cyl(bm, 0.12, 0.14, (0.72, -1.33, 0.35), "Y", 12, M=M)


def battery_case_geo(bm, M):
    # Envelope 1.2 x 1.0 x 1.0 centered at the origin.
    cube(bm, (1.2, 1.0, 0.86), (0, 0, -0.07), M)
    cube(bm, (1.12, 0.92, 0.16), (0, 0, 0.42), M)


# ---------------------------------------------------------------- Sedan v3

WX, WY, WZ = 2.9, 4.4, 1.32
WHEELS = (("Wheel_FL", WX, -WY), ("Wheel_FR", -WX, -WY), ("Wheel_RL", WX, WY), ("Wheel_RR", -WX, WY))
BODY_HALF = 3.5
CAB_BOT = (3.15, -2.55, 3.85, 3.3)
CAB_TOP = (2.85, -0.7, 2.9, 5.75)
CAB_SIDE = [(CAB_BOT[1], CAB_BOT[3]), (CAB_BOT[2], CAB_BOT[3]), (CAB_TOP[2], CAB_TOP[3]), (CAB_TOP[1], CAB_TOP[3])]


def cab_x(z):
    return CAB_BOT[0] - (z - CAB_BOT[3]) * (CAB_BOT[0] - CAB_TOP[0]) / (CAB_TOP[3] - CAB_BOT[3])


def along(p, q, z):
    return p[0] + (q[0] - p[0]) * (z - p[1]) / (q[1] - p[1])


def cab_loft(bm, d, zb):
    # Cabin loft inset by d, running from height zb up to the inset roof.
    g = inset_poly(CAB_SIDE, d)
    zt = g[2][1]
    loft(bm, (cab_x(zb) - d, along(g[0], g[3], zb), along(g[1], g[2], zb), zb), (cab_x(zt) - d, g[3][0], g[2][0], zt))


def build_sedan(objs):
    P = "Sedan__"
    profile = [
        (-6.6, 0.6), (6.55, 0.6), (6.8, 1.2), (6.8, 2.7), (6.5, 3.3), (3.9, 3.35),
        (-2.55, 3.35), (-2.75, 3.15), (-6.55, 3.15), (-6.85, 2.75), (-6.85, 1.2),
    ]
    bm = bmesh.new()
    prism(bm, profile, -BODY_HALF, BODY_HALF, "X")
    body = obj(P + "Body", bm, MAT["paint"], 0.42, 5)
    cutters = []
    for name, x, y in WHEELS:
        bm = bmesh.new()
        cyl(bm, 1.55, 1.9, (math.copysign(3.1, x), y, WZ), "X", 40)
        cutters.append(obj("_cut", bm))
    for size, center in (((4.0, 3.5, 3.0), (0, -4.5, 2.5)), ((5.9, 5.1, 3.0), (0, 0.1, 2.5)), ((4.0, 1.2, 3.0), (0, 3.15, 2.5))):
        bm = bmesh.new()
        cube(bm, size, center)
        cutters.append(obj("_cut", bm))
    objs.append(cut(body, cutters))

    bm = bmesh.new()
    cube(bm, (5.9, 3.95, 0.16), (0, -4.575, 3.23))
    objs.append(obj(P + "Panel_Hood", bm, MAT["paint"], 0.07, 3))
    for name, s in (("Panel_Left", 1), ("Panel_Right", -1)):
        bm = bmesh.new()
        cube(bm, (0.14, 5.0, 1.75), (s * 3.56, 0.1, 2.125))
        objs.append(obj(P + name, bm, MAT["paint"], 0.06, 3))

    # Greenhouse frame: outer loft, hollowed, with window openings.
    bm = bmesh.new()
    loft(bm, CAB_BOT, CAB_TOP)
    bevel_except_z(bm, 0.3, 4, CAB_BOT[3])
    cabin = obj(P + "Cabin", bm, MAT["paint"])
    bm = bmesh.new()
    cab_loft(bm, 0.16, CAB_BOT[3] - 0.3)
    cutters = [obj("_cut", bm)]
    win = clip(inset_poly(CAB_SIDE, 0.3), 1, 3.62, False)
    for poly in (clip(win, 0, 0.85, True), clip(win, 0, 1.25, False)):
        for s in (1, -1):
            bm = bmesh.new()
            prism(bm, poly, s * 2.3, s * 4.0, "X")
            cutters.append(obj("_cut", bm))
    shield = [(-2.6, 3.62), (2.6, 3.62), (2.3, 5.42), (-2.3, 5.42)]
    for a0, a1 in ((-3.4, -0.3), (2.0, 5.0)):
        bm = bmesh.new()
        prism(bm, shield, a0, a1, "Y")
        cutters.append(obj("_cut", bm))
    objs.append(cut(cabin, cutters))

    bm = bmesh.new()
    cab_loft(bm, 0.08, CAB_BOT[3] + 0.08)
    bevel_except_z(bm, 0.24, 3, CAB_BOT[3] + 0.08)
    objs.append(obj(P + "Glass", bm, MAT["glass"]))

    bm = bmesh.new()
    cube(bm, (5.3, 3.4, 0.2), (0, 1.1, 5.8))
    objs.append(obj(P + "Roof", bm, MAT["paint"], 0.08, 3))

    # Interior: floor, dash, console, seats, steering wheel.
    bm = bmesh.new()
    cube(bm, (5.8, 5.0, 0.1), (0, 0.1, 1.05))
    cube(bm, (5.8, 0.7, 0.9), (0, -2.05, 2.85))
    cube(bm, (0.6, 2.6, 0.5), (0, -0.4, 1.35))
    tilt = Matrix.Translation((0, 1.15, 1.9)) @ Matrix.Rotation(math.radians(-10), 4, "X") @ Matrix.Translation((0, -1.15, -1.9))
    for s in (1, -1):
        cube(bm, (1.7, 1.6, 0.8), (s * 1.3, 0.35, 1.5))
        cube(bm, (1.6, 0.4, 2.0), (s * 1.3, 1.15, 2.85), tilt)
    cube(bm, (4.0, 1.2, 0.7), (0, 2.15, 1.45))
    cube(bm, (4.0, 0.4, 1.8), (0, 2.85, 2.55))
    ring = bmesh.new()
    revolve(ring, [(-0.05, 0.36), (0.05, 0.36), (0.05, 0.46), (-0.05, 0.46)], (0, 0, 0), "Z", 24)
    merge(bm, ring, Matrix.Translation((1.3, -1.45, 2.95)) @ Matrix.Rotation(math.radians(-60), 4, "X"))
    column = Matrix.Translation((1.3, -1.7, 2.75)) @ Matrix.Rotation(math.radians(30), 4, "X")
    cube(bm, (0.12, 0.12, 0.7), (0, 0, 0), column)
    objs.append(obj(P + "Interior", bm, MAT["interior"], 0.06, 2))

    # Front and rear detail.
    bm = bmesh.new()
    for s in (1, -1):
        cube(bm, (1.3, 0.2, 0.6), (s * 2.35, -6.85, 2.25))
    objs.append(obj(P + "Headlight", bm, MAT["head"], 0.12, 3))
    bm = bmesh.new()
    for s in (1, -1):
        cube(bm, (1.4, 0.2, 0.55), (s * 2.4, 6.82, 2.32))
    objs.append(obj(P + "Taillight", bm, MAT["tail"], 0.1, 3))
    bm = bmesh.new()
    cube(bm, (2.7, 0.14, 0.95), (0, -6.85, 2.0))
    for k in range(3):
        cube(bm, (2.5, 0.12, 0.09), (0, -6.92, 1.72 + k * 0.28))
    objs.append(obj(P + "Grille", bm, MAT["trim"], 0.04, 2))
    for name, y in (("BumperFront", -6.92), ("BumperRear", 6.87)):
        bm = bmesh.new()
        cube(bm, (6.7, 0.55, 0.8), (0, y, 0.95))
        objs.append(obj(P + name, bm, MAT["trim"], 0.22, 4))
    bm = bmesh.new()
    cube(bm, (1.5, 0.06, 0.48), (0, -7.21, 0.98))
    cube(bm, (1.5, 0.06, 0.48), (0, 7.16, 0.98))
    objs.append(obj(P + "Plate", bm, MAT["white"], 0.03, 2))
    bm = bmesh.new()
    cyl(bm, 0.16, 0.5, (-2.1, 7.1, 0.55), "Y", 16)
    objs.append(obj(P + "Exhaust", bm, MAT["chrome"]))
    bm = bmesh.new()
    for s in (1, -1):
        cube(bm, (0.55, 0.32, 0.4), (s * 3.55, -2.05, 3.8))
        cube(bm, (0.4, 0.14, 0.14), (s * 3.25, -2.05, 3.62))
    objs.append(obj(P + "Mirror", bm, MAT["paint"], 0.1, 3))
    bm = bmesh.new()
    for s in (1, -1):
        for y in (-0.55, 1.85):
            cube(bm, (0.1, 0.5, 0.13), (s * 3.66, y, 2.7))
        cube(bm, (0.04, 0.05, 1.55), (s * 3.64, 0.75, 2.12))
    objs.append(obj(P + "Handle", bm, MAT["trim"], 0.02, 2))
    bm = bmesh.new()
    for name, x, y in WHEELS:
        prof = [(3.3, 1.55), (3.64, 1.55), (3.64, 1.74), (3.3, 1.74)]
        if x < 0:
            prof = [(-a, r) for a, r in reversed(prof)]
        revolve(bm, prof, (0, y, WZ), "X", segs=24, start=-0.42, sweep=math.pi + 0.84)
    for s in (1, -1):
        cube(bm, (0.18, 5.4, 0.42), (s * 3.47, 0, 0.78))
    objs.append(obj(P + "ArchTrim", bm, MAT["trim"]))

    # Engine bay. The battery sits front-right (Blender -X, -Y).
    E = Matrix.Translation((0, -3.95, 1.68)) @ Matrix.Scale(0.85, 4)
    bm = bmesh.new()
    engine_geo(bm, E)
    pulley_geo(bm, E)
    exhaust_geo(bm, E)
    intake_geo(bm, E)
    objs.append(obj(P + "EngineBlock", bm, MAT["metal"], 0.05, 2))
    bm = bmesh.new()
    valve_cover_geo(bm, E)
    objs.append(obj(P + "EngineCover", bm, MAT["accent"], 0.05, 2))
    bm = bmesh.new()
    cyl(bm, 0.17, 0.18, ((E @ Vector((0.42, 0, 0))).x, -3.6, (E @ Vector((0, 0, 1.0))).z + 0.03), "Z", 16)
    objs.append(obj(P + "OilCap", bm, MAT["yellow"], 0.03, 2))
    bm = bmesh.new()
    battery_case_geo(bm, Matrix.Translation((-1.35, -5.55, 1.52)))
    objs.append(obj(P + "Battery", bm, MAT["battery"], 0.05, 2))
    bm = bmesh.new()
    cube(bm, (3.7, 0.18, 1.7), (0, -6.14, 2.0))
    cube(bm, (1.3, 1.0, 0.9), (1.25, -5.55, 2.05))
    cyl(bm, 0.2, 0.5, (0.75, -4.85, 2.25), "Y", 12)
    for s in (1, -1):
        cyl(bm, 0.26, 1.5, (s * 1.68, -4.4, 1.75), "Z", 16)
    cyl(bm, 0.42, 0.5, (1.4, -3.15, 2.0), "Y", 20)
    objs.append(obj(P + "BayTrim", bm, MAT["trim"], 0.05, 2))
    bm = bmesh.new()
    cube(bm, (0.6, 0.6, 0.7), (-1.5, -3.25, 1.9))
    objs.append(obj(P + "Reservoir", bm, MAT["white"], 0.08, 2))

    for name, x, y in WHEELS:
        bm = bmesh.new()
        tire_geo(bm, (x, y, WZ))
        objs.append(obj(P + name, bm, MAT["rubber"]))
        bm = bmesh.new()
        hub_geo(bm, (x, y, WZ))
        objs.append(obj(P + name + "_Hub", bm, MAT["chrome"]))


# ---------------------------------------------------------------- Parts kit


def build_kit(objs):
    E = Matrix.Translation((-12, -5, 0.7))
    bm = bmesh.new()
    engine_geo(bm, E)
    objs.append(obj("Engine__Block", bm, MAT["metal"], 0.06, 2))
    bm = bmesh.new()
    valve_cover_geo(bm, E)
    objs.append(obj("Engine__ValveCover", bm, MAT["chrome"], 0.05, 2))
    bm = bmesh.new()
    intake_geo(bm, E)
    objs.append(obj("Engine__Intake", bm, MAT["chrome"], 0.04, 2))
    bm = bmesh.new()
    exhaust_geo(bm, E)
    objs.append(obj("Engine__Exhaust", bm, MAT["darkmetal"], 0.04, 2))
    bm = bmesh.new()
    pulley_geo(bm, E)
    objs.append(obj("Engine__Pulleys", bm, MAT["rubber"], 0.03, 2))

    T = Matrix.Translation((-12, -0.5, 0.5))
    bm = bmesh.new()
    bell = bmesh.new()
    cyl(bell, 0.8, 0.8, (0, -0.6, 0), "Y", 24, 0.52)
    merge(bm, bell, T @ Matrix.Diagonal((1, 1, 0.625, 1)))
    cube(bm, (0.95, 0.85, 0.8), (0, 0.18, -0.05), T)
    cyl(bm, 0.24, 0.45, (0, 0.78, 0.0), "Y", 16, 0.2, M=T)
    for k in range(3):
        cube(bm, (0.12, 0.7, 0.06), (-0.3 + k * 0.3, 0.18, 0.37), T)
    objs.append(obj("Transmission__Case", bm, MAT["metal"], 0.05, 2))
    bm = bmesh.new()
    cube(bm, (0.75, 0.7, 0.1), (0, 0.18, -0.45), T)
    objs.append(obj("Transmission__Pan", bm, MAT["darkmetal"], 0.03, 2))
    bm = bmesh.new()
    cyl(bm, 0.15, 0.16, (0, 1.06, 0), "Y", 12, M=T)
    objs.append(obj("Transmission__Yoke", bm, MAT["chrome"], 0.02, 2))

    B = Matrix.Translation((-12, 3.5, 0.5))
    bm = bmesh.new()
    battery_case_geo(bm, B)
    objs.append(obj("Battery__Case", bm, MAT["battery"], 0.05, 2))
    bm = bmesh.new()
    cyl(bm, 0.1, 0.18, (0.36, -0.22, 0.58), "Z", 12, M=B)
    objs.append(obj("Battery__TerminalPos", bm, MAT["red"], 0.02, 2))
    bm = bmesh.new()
    cyl(bm, 0.1, 0.18, (-0.36, -0.22, 0.58), "Z", 12, M=B)
    objs.append(obj("Battery__TerminalNeg", bm, MAT["trim"], 0.02, 2))
    bm = bmesh.new()
    cube(bm, (0.9, 0.03, 0.32), (0, -0.505, -0.02), B)
    objs.append(obj("Battery__Label", bm, MAT["yellow"], 0.01, 1))

    S = Matrix.Translation((-17, -4, 0.5))
    bm = bmesh.new()
    cube(bm, (1.9, 2.1, 0.2), (0, 0, -0.4), S)
    cube(bm, (2.0, 2.4, 0.55), (0, 0, -0.05), S)
    for s in (1, -1):
        cube(bm, (0.38, 2.2, 0.72), (s * 1.01, 0, 0.14), S)
    objs.append(obj("Seat__Cushion", bm, MAT["fabric"], 0.14, 3))
    tilt = S @ Matrix.Translation((0, 1.0, 0.3)) @ Matrix.Rotation(math.radians(-12), 4, "X") @ Matrix.Translation((0, -1.0, -0.3))
    bm = bmesh.new()
    cube(bm, (2.0, 0.45, 2.2), (0, 0.95, 1.35), tilt)
    for s in (1, -1):
        cube(bm, (0.36, 0.62, 1.9), (s * 1.0, 0.95, 1.25), tilt)
        cube(bm, (0.08, 0.08, 0.4), (s * 0.35, 1.0, 2.45), tilt)
    cube(bm, (1.1, 0.4, 0.55), (0, 1.0, 2.85), tilt)
    objs.append(obj("Seat__Back", bm, MAT["fabric"], 0.14, 3))

    bm = bmesh.new()
    tire_geo(bm, (-17, 3.5, TIRE_R))
    objs.append(obj("Wheel__Tire", bm, MAT["rubber"]))
    bm = bmesh.new()
    hub_geo(bm, (-17, 3.5, TIRE_R))
    objs.append(obj("Wheel__Hub", bm, MAT["chrome"]))


def finish(ob, angle=34):
    # Smooth by angle, then move the origin to the bounding-box center (Roblox centers MeshParts there).
    me = ob.data
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    me.set_sharp_from_angle(angle=math.radians(angle))
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    c = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2))
    me.transform(Matrix.Translation(-c))
    ob.location = c
    me.update()


ALL = []
build_sedan(ALL)
build_kit(ALL)
for ob in ALL:
    finish(ob)
print("built", len(ALL), "objects,", sum(len(o.data.polygons) for o in ALL), "faces")
for ob in ALL:
    print(ob.name, tuple(round(v, 3) for v in ob.dimensions), len(ob.data.polygons))
