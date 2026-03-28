bl_info = {
    "name": "Spatial Mouse",
    "author": "You",
    "version": (0, 5, 2),
    "blender": (4, 2, 0),
    "category": "3D View",
}

import bpy
from bpy.props import BoolProperty, FloatProperty, IntProperty

from .server import ControlServer
from .dispatcher import handle_message, reset_control_state

_server = None


class PSM_OT_start_server(bpy.types.Operator):
    bl_idname = "psm.start_server"
    bl_label = "Start Spatial Mouse Server"

    def execute(self, context):
        global _server
        if _server is None:
            port = context.scene.psm_port
            _server = ControlServer(port=port)
            _server.start()
            bpy.app.timers.register(timer_tick)
            self.report({'INFO'}, f"Server started on port {port}")
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


def unregister():
    global _server

    if _server is not None:
        _server.stop()
        _server = None

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
