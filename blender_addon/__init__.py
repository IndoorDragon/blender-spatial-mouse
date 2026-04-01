bl_info = {
    "name": "Spatial Mouse",
    "author": "You",
    "version": (0, 1, 0),
    "blender": (4, 2, 0),
    "category": "3D View",
}

import os
import sys

ADDON_DIR = os.path.dirname(__file__)
THIRD_PARTY_DIR = os.path.join(ADDON_DIR, "third_party")

if THIRD_PARTY_DIR not in sys.path:
    sys.path.insert(0, THIRD_PARTY_DIR)

import bpy
import bpy.utils.previews
from bpy.props import BoolProperty, FloatProperty, IntProperty, StringProperty

from .server import ControlServer
from .dispatcher import handle_message, reset_control_state
from .qr_utils import generate_connection_qr, get_best_lan_ip

_server = None
_preview_collection = None


def ensure_preview_collection():
    global _preview_collection
    if _preview_collection is None:
        _preview_collection = bpy.utils.previews.new()
    return _preview_collection


def clear_preview_collection():
    global _preview_collection
    if _preview_collection is not None:
        bpy.utils.previews.remove(_preview_collection)
        _preview_collection = None


def load_qr_preview(filepath: str):
    pcoll = ensure_preview_collection()

    if "psm_qr" in pcoll:
        del pcoll["psm_qr"]

    if filepath and os.path.exists(filepath):
        pcoll.load("psm_qr", filepath, 'IMAGE')


class PSM_OT_start_server(bpy.types.Operator):
    bl_idname = "psm.start_server"
    bl_label = "Start Spatial Mouse Server"

    def execute(self, context):
        global _server

        if _server is None:
            scene = context.scene
            port = scene.psm_port

            _server = ControlServer(port=port)
            _server.start()

            local_ip = get_best_lan_ip()
            qr_path, payload = generate_connection_qr(local_ip, port, ADDON_DIR)

            scene.psm_last_host = local_ip
            scene.psm_last_qr_path = qr_path
            scene.psm_last_qr_payload = payload

            load_qr_preview(qr_path)

            bpy.app.timers.register(timer_tick)
            self.report({'INFO'}, f"Server started on {local_ip}:{port}")

            print("Spatial Mouse server started")
            print("Host:", local_ip)
            print("Port:", port)
            print("QR file:", qr_path)
            print("QR payload:", payload)

        return {'FINISHED'}


class PSM_OT_stop_server(bpy.types.Operator):
    bl_idname = "psm.stop_server"
    bl_label = "Stop Spatial Mouse Server"

    def execute(self, context):
        global _server
        if _server is not None:
            _server.stop()
            _server = None
            self.report({'INFO'}, "Server stopped")
        return {'FINISHED'}


class PSM_OT_reset_control_state(bpy.types.Operator):
    bl_idname = "psm.reset_control_state"
    bl_label = "Reset Control State"

    def execute(self, context):
        reset_control_state()
        self.report({'INFO'}, "Control state reset")
        return {'FINISHED'}


class PSM_PT_panel(bpy.types.Panel):
    bl_label = "Spatial Mouse"
    bl_idname = "PSM_PT_panel"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = "Spatial Mouse"

    def draw(self, context):
        layout = self.layout
        scene = context.scene

        layout.prop(scene, "psm_port")
        row = layout.row(align=True)
        row.operator("psm.start_server")
        row.operator("psm.stop_server")

        layout.separator()
        layout.label(text="Connection")
        layout.label(text=f"Host: {scene.psm_last_host or 'Not started'}")
        layout.label(text=f"Payload: {scene.psm_last_qr_payload or 'Not generated'}")

        pcoll = ensure_preview_collection()
        if "psm_qr" in pcoll:
            layout.separator()
            layout.label(text="Scan to Connect")
            box = layout.box()
            box.template_icon(icon_value=pcoll["psm_qr"].icon_id, scale=12)

        layout.separator()
        layout.label(text="Control Settings")
        layout.prop(scene, "psm_move_scale")
        layout.prop(scene, "psm_rotation_scale")
        layout.prop(scene, "psm_smoothing")
        layout.label(text="0 = immediate, higher = smoother")
        layout.operator("psm.reset_control_state")

        layout.separator()
        layout.prop(scene, "psm_show_advanced_strength")

        if scene.psm_show_advanced_strength:
            box = layout.box()
            box.label(text="Translation Strength")
            box.prop(scene, "psm_left_right_strength")
            box.prop(scene, "psm_up_down_strength")
            box.prop(scene, "psm_forward_back_strength")

            box = layout.box()
            box.label(text="Rotation Strength")
            box.prop(scene, "psm_pitch_strength")
            box.prop(scene, "psm_roll_strength")
            box.prop(scene, "psm_yaw_strength")


def timer_tick():
    global _server

    if _server is None or not _server.is_running:
        return None

    for msg in _server.pop_incoming():
        handle_message(msg)

    return 0.02


classes = (
    PSM_OT_start_server,
    PSM_OT_stop_server,
    PSM_OT_reset_control_state,
    PSM_PT_panel,
)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)

    ensure_preview_collection()

    bpy.types.Scene.psm_port = IntProperty(
        name="Port",
        default=5000,
        min=1024,
        max=65535,
    )

    bpy.types.Scene.psm_move_scale = FloatProperty(
        name="Move Scale",
        default=1.0,
        min=0.001,
        max=100.0,
    )

    bpy.types.Scene.psm_rotation_scale = FloatProperty(
        name="Rotation Scale",
        default=1.0,
        min=0.001,
        max=10.0,
    )

    bpy.types.Scene.psm_smoothing = FloatProperty(
        name="Control Smoothing",
        description="0 = immediate response, higher values = stronger smoothing",
        default=6.0,
        min=0.0,
        max=20.0,
    )

    bpy.types.Scene.psm_show_advanced_strength = BoolProperty(
        name="Show Advanced Strength",
        default=False,
    )

    bpy.types.Scene.psm_left_right_strength = FloatProperty(
        name="Left / Right",
        default=1.0,
        min=0.001,
        max=10.0,
    )

    bpy.types.Scene.psm_up_down_strength = FloatProperty(
        name="Up / Down",
        default=1.0,
        min=0.001,
        max=10.0,
    )

    bpy.types.Scene.psm_forward_back_strength = FloatProperty(
        name="Forward / Back",
        default=1.0,
        min=0.001,
        max=10.0,
    )

    bpy.types.Scene.psm_pitch_strength = FloatProperty(
        name="Pitch",
        default=1.0,
        min=0.001,
        max=10.0,
    )

    bpy.types.Scene.psm_roll_strength = FloatProperty(
        name="Roll",
        default=1.0,
        min=0.001,
        max=10.0,
    )

    bpy.types.Scene.psm_yaw_strength = FloatProperty(
        name="Yaw",
        default=1.0,
        min=0.001,
        max=10.0,
    )

    bpy.types.Scene.psm_last_host = StringProperty(
        name="Last Host",
        default="",
    )

    bpy.types.Scene.psm_last_qr_path = StringProperty(
        name="Last QR Path",
        default="",
    )

    bpy.types.Scene.psm_last_qr_payload = StringProperty(
        name="Last QR Payload",
        default="",
    )


def unregister():
    global _server

    if _server is not None:
        _server.stop()
        _server = None

    clear_preview_collection()

    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)

    del bpy.types.Scene.psm_port
    del bpy.types.Scene.psm_move_scale
    del bpy.types.Scene.psm_rotation_scale
    del bpy.types.Scene.psm_smoothing
    del bpy.types.Scene.psm_show_advanced_strength
    del bpy.types.Scene.psm_left_right_strength
    del bpy.types.Scene.psm_up_down_strength
    del bpy.types.Scene.psm_forward_back_strength
    del bpy.types.Scene.psm_pitch_strength
    del bpy.types.Scene.psm_roll_strength
    del bpy.types.Scene.psm_yaw_strength
    del bpy.types.Scene.psm_last_host
    del bpy.types.Scene.psm_last_qr_path
    del bpy.types.Scene.psm_last_qr_payload