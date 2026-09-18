import bpy
import math
from mathutils import Vector
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "design" / "speedometer-icon"
BLEND_PATH = OUTPUT_DIR / "SpeedometerIcon.blend"
RENDER_PATH = OUTPUT_DIR / "SpeedometerIcon.png"


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.materials, bpy.data.curves, bpy.data.meshes, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def material(name, color, metallic=0.0, roughness=0.45, coat=0.0, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color[:3], color[3])
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    values = {
        "Base Color": color,
        "Metallic": metallic,
        "Roughness": roughness,
        "Coat Weight": coat,
        "Coat Roughness": max(0.03, roughness * 0.35),
    }
    if emission:
        values["Emission Color"] = emission[0]
        values["Emission Strength"] = emission[1]
    for key, value in values.items():
        socket = bsdf.inputs.get(key)
        if socket is not None:
            socket.default_value = value
    return mat


def bevel(obj, width, segments=6):
    mod = obj.modifiers.new("Soft machined edges", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in obj.data.polygons:
        poly.use_smooth = True


def cube(name, location, scale, mat, bevel_width=0.0):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel_width:
        bevel(obj, bevel_width)
    obj.data.materials.append(mat)
    return obj


def cylinder(name, radius, depth, z, mat, vertices=128, bevel_width=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=(0, 0, z))
    obj = bpy.context.object
    obj.name = name
    if bevel_width:
        bevel(obj, bevel_width, 5)
    obj.data.materials.append(mat)
    return obj


def ring(name, outer_radius, inner_radius, depth, z, mat, segments=160):
    verts = []
    faces = []
    for layer_z in (-depth / 2, depth / 2):
        for radius in (outer_radius, inner_radius):
            for i in range(segments):
                a = 2 * math.pi * i / segments
                verts.append((radius * math.cos(a), radius * math.sin(a), z + layer_z))
    outer_bottom = 0
    inner_bottom = segments
    outer_top = segments * 2
    inner_top = segments * 3
    for i in range(segments):
        j = (i + 1) % segments
        faces.extend([
            (outer_top + i, outer_top + j, inner_top + j, inner_top + i),
            (outer_bottom + j, outer_bottom + i, inner_bottom + i, inner_bottom + j),
            (outer_bottom + i, outer_bottom + j, outer_top + j, outer_top + i),
            (inner_bottom + j, inner_bottom + i, inner_top + i, inner_top + j),
        ])
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bevel(obj, 0.035, 3)
    return obj


def tick_marks(mat_major, mat_minor):
    # Deliberately sparse: readable at 16 px and avoids dashboard visual noise.
    start = math.radians(-145)
    end = math.radians(145)
    for i in range(21):
        a = start + (end - start) * i / 20
        major = i % 5 == 0
        radius = 2.03
        length = 0.34 if major else 0.20
        width = 0.055 if major else 0.032
        x = radius * math.sin(a)
        y = radius * math.cos(a)
        tick = cube(
            f"{'Major' if major else 'Minor'} tick {i:02d}",
            (x, y, 0.79),
            (width, length / 2, 0.025),
            mat_major if major else mat_minor,
            0.025,
        )
        tick.rotation_euler[2] = -a


def create_needle(coral, coral_dark):
    # A tapered, counterweighted pointer cut as one clean silhouette.
    angle = math.radians(-52)
    verts_2d = [(-0.11, -0.52), (0.11, -0.52), (0.075, 1.70), (0.0, 2.06), (-0.075, 1.70)]
    depth = 0.12
    verts = [(x, y, 0.90 - depth / 2) for x, y in verts_2d] + [(x, y, 0.90 + depth / 2) for x, y in verts_2d]
    faces = [(0, 1, 2, 3, 4), (9, 8, 7, 6, 5)]
    n = len(verts_2d)
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    mesh = bpy.data.meshes.new("NeedleMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    needle = bpy.data.objects.new("Coral speed needle", mesh)
    bpy.context.collection.objects.link(needle)
    needle.data.materials.append(coral)
    needle.rotation_euler[2] = angle
    bevel(needle, 0.045, 4)

    hub = cylinder("Needle hub", 0.39, 0.22, 1.02, coral, bevel_width=0.055)
    cap = cylinder("Needle hub inset", 0.19, 0.07, 1.165, coral_dark, bevel_width=0.025)
    return needle, hub, cap


def setup_camera_and_lighting():
    bpy.ops.object.camera_add(location=(0, -8.8, 12.8))
    camera = bpy.context.object
    camera.name = "Icon camera"
    target = Vector((0, 0, 0.25))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 9.55
    camera.data.lens = 55
    bpy.context.scene.camera = camera

    def area(name, location, energy, size, color):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        light.data.color = color
        light.rotation_euler = (target - light.location).to_track_quat("-Z", "Y").to_euler()
        return light

    area("Large softbox", (-4.5, -4.0, 9.0), 1150, 5.0, (0.86, 0.93, 1.0))
    area("Warm rim", (5.5, 1.0, 6.0), 900, 3.5, (1.0, 0.46, 0.30))
    area("Face fill", (0.0, -1.5, 8.0), 650, 4.0, (0.70, 0.83, 1.0))


def build_scene():
    clear_scene()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    navy = material("Midnight blue enamel", (0.025, 0.055, 0.105, 1), metallic=0.05, roughness=0.24, coat=0.38)
    navy_edge = material("Housing edge", (0.012, 0.025, 0.052, 1), metallic=0.10, roughness=0.32)
    steel = material("Brushed warm aluminum", (0.66, 0.70, 0.72, 1), metallic=0.82, roughness=0.27, coat=0.12)
    steel_dark = material("Bezel inner bevel", (0.20, 0.24, 0.27, 1), metallic=0.72, roughness=0.32)
    dial = material("Ink dial", (0.013, 0.021, 0.034, 1), metallic=0.02, roughness=0.39)
    tick_major = material("Warm tick", (0.84, 0.86, 0.85, 1), metallic=0.12, roughness=0.40)
    tick_minor = material("Dim tick", (0.35, 0.40, 0.43, 1), metallic=0.08, roughness=0.48)
    coral = material("Coral enamel", (0.98, 0.16, 0.19, 1), metallic=0.03, roughness=0.22, coat=0.48)
    coral_dark = material("Coral hub shadow", (0.43, 0.025, 0.038, 1), metallic=0.10, roughness=0.32)
    cyan = material("Network cyan", (0.03, 0.67, 0.91, 1), metallic=0.12, roughness=0.22, emission=((0.02, 0.30, 0.55, 1), 0.8))

    housing = cube("Rounded midnight housing", (0, 0, 0), (3.75, 3.75, 0.42), navy, 0.72)
    # A darker lower lip gives the slab physical thickness in the oblique icon view.
    lower = cube("Lower housing lip", (0, 0.08, -0.34), (3.55, 3.55, 0.28), navy_edge, 0.62)
    lower.parent = housing

    cylinder("Gauge recess", 2.98, 0.28, 0.42, steel_dark, bevel_width=0.10)
    ring("Machined bezel", 3.02, 2.61, 0.30, 0.61, steel)
    cylinder("Dial face", 2.60, 0.18, 0.69, dial, bevel_width=0.055)
    tick_marks(tick_major, tick_minor)

    # A single cyan status jewel hints at live connectivity without introducing a second gauge.
    indicator = cylinder("Network status jewel", 0.095, 0.06, 0.84, cyan, vertices=64, bevel_width=0.025)
    indicator.location.x = -1.78
    indicator.location.y = -1.42

    create_needle(coral, coral_dark)

    # Fine concentric groove: subtle at full size, useful edge contrast when downsampled.
    ring("Dial groove", 2.36, 2.32, 0.035, 0.805, tick_minor)

    setup_camera_and_lighting()

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.render.filepath = str(RENDER_PATH)
    scene.render.image_settings.color_depth = "8"
    scene.render.resolution_percentage = 100
    scene.render.use_file_extension = True
    scene.view_settings.look = "AgX - Medium High Contrast"

    world = scene.world or bpy.data.worlds.new("Icon world")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.008, 0.014, 0.027, 1)
    bg.inputs["Strength"].default_value = 0.24

    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build_scene()
