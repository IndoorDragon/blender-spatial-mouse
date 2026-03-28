import bpy
from mathutils import Vector, Quaternion, Matrix
from .protocol import (
    MSG_SET_MODE,
    MSG_CONTROL_INPUT,
    MODE_SPATIAL_MOUSE,
)

CURRENT_MODE = MODE_SPATIAL_MOUSE

BAD_TRACKING = {
    "not_available",
    "limited_initializing",
    "limited_relocalizing",
}

_control_target_kind = None   # "OBJECT" or "POSE_BONE"
_control_object_name = None
_control_bone_name = None
_control_object_start_matrix = None
_control_bone_start_matrix = None  # Stored in POSE space (armature object space)


def reset_control_state():
    global _control_target_kind
    global _control_object_name
    global _control_bone_name
    global _control_object_start_matrix
    global _control_bone_start_matrix

    _control_target_kind = None
    _control_object_name = None
    _control_bone_name = None
    _control_object_start_matrix = None
    _control_bone_start_matrix = None
    print("Control state cleared")


def handle_message(msg):
    global CURRENT_MODE

    msg_type = msg.get("type")

    if msg_type == MSG_SET_MODE:
        mode = msg.get("mode")
        if mode == MODE_SPATIAL_MOUSE:
            if mode != CURRENT_MODE:
                reset_control_state()
            CURRENT_MODE = mode
            print("Mode set to", mode)
        return

    if msg_type == MSG_CONTROL_INPUT and CURRENT_MODE == MODE_SPATIAL_MOUSE:
        _apply_control_input(msg)
        return


def _capture_current_control_target():
    obj = bpy.context.view_layer.objects.active
    if obj is None:
        print("Control: no active object")
        return None, None, None

    if obj.type == 'ARMATURE' and obj.mode == 'POSE':
        pbone = bpy.context.active_pose_bone
        if pbone is not None:
            print(f"Control: active pose bone detected: {obj.name} / {pbone.name}")
            return "POSE_BONE", obj, pbone
        else:
            print("Control: armature is in POSE mode but no active pose bone found")

    print(f"Control: falling back to object mode target: {obj.name}")
    return "OBJECT", obj, None


def _find_reference_view_rotation():
    ctx = bpy.context

    area = getattr(ctx, "area", None)
    space = getattr(ctx, "space_data", None)
    if area is not None and area.type == 'VIEW_3D' and space is not None and space.type == 'VIEW_3D':
        return space.region_3d.view_rotation.copy()

    window = getattr(ctx, "window", None)
    if window is not None:
        for area in window.screen.areas:
            if area.type != 'VIEW_3D':
                continue
            for space in area.spaces:
                if space.type == 'VIEW_3D':
                    return space.region_3d.view_rotation.copy()

    for window in ctx.window_manager.windows:
        for area in window.screen.areas:
            if area.type != 'VIEW_3D':
                continue
            for space in area.spaces:
                if space.type == 'VIEW_3D':
                    return space.region_3d.view_rotation.copy()

    return Quaternion((1.0, 0.0, 0.0, 0.0))


def _build_view_relative_motion(
    tx, ty, tz, rx, ry, rz,
    move_scale, rot_scale,
    orientation_quat,
    left_right_strength=1.0,
    up_down_strength=1.0,
    forward_back_strength=1.0,
    pitch_strength=1.0,
    roll_strength=1.0,
    yaw_strength=1.0,
):
    right_vec = (orientation_quat @ Vector((1.0, 0.0, 0.0))).normalized()
    up_vec = (orientation_quat @ Vector((0.0, 1.0, 0.0))).normalized()
    forward_vec = (orientation_quat @ Vector((0.0, 0.0, -1.0))).normalized()

    delta_loc = (
        right_vec * (ty * move_scale * left_right_strength) +
        up_vec * (-tx * move_scale * up_down_strength) +
        forward_vec * (-tz * move_scale * forward_back_strength)
    )

    pitch_angle = rx * rot_scale * pitch_strength
    yaw_angle = ry * rot_scale * yaw_strength
    roll_angle = -rz * rot_scale * roll_strength

    delta_rot = (
        Quaternion(up_vec, yaw_angle) @
        Quaternion(right_vec, pitch_angle) @
        Quaternion(forward_vec, roll_angle)
    )

    return delta_loc, delta_rot


def _smoothing_amount_to_blend(smoothing_amount):
    if smoothing_amount <= 0.0:
        return 1.0
    return 1.0 / (1.0 + smoothing_amount)


def _pose_matrix_to_basis_matrix(pbone, pose_matrix):
    parent_pose_matrix = pbone.parent.matrix.copy() if pbone.parent else Matrix.Identity(4)
    parent_rest_matrix = pbone.parent.bone.matrix_local.copy() if pbone.parent else Matrix.Identity(4)

    return pbone.bone.convert_local_to_pose(
        pose_matrix,
        pbone.bone.matrix_local,
        parent_matrix=parent_pose_matrix,
        parent_matrix_local=parent_rest_matrix,
        invert=True,
    )


def _apply_control_input(msg):
    global _control_target_kind
    global _control_object_name
    global _control_bone_name
    global _control_object_start_matrix
    global _control_bone_start_matrix

    tracking = msg.get("tracking", "unknown")
    if tracking in BAD_TRACKING:
        return

    active = bool(msg.get("active", False))
    if not active:
        reset_control_state()
        return

    scene = bpy.context.scene

    if _control_target_kind is None:
        target_kind, obj, bone = _capture_current_control_target()
        if target_kind is None or obj is None:
            return

        _control_target_kind = target_kind
        _control_object_name = obj.name

        if target_kind == "POSE_BONE":
            _control_bone_name = bone.name
            _control_bone_start_matrix = bone.matrix.copy()
            print(f"Control started with pose bone: {_control_object_name} / {_control_bone_name}")
        else:
            _control_bone_name = None
            _control_object_start_matrix = obj.matrix_world.copy()
            print(f"Control started with object: {_control_object_name}")

    obj = bpy.data.objects.get(_control_object_name)
    if obj is None:
        reset_control_state()
        return

    t = msg.get("translation", {})
    r = msg.get("rotation", {})

    tx = float(t.get("x", 0.0))
    ty = float(t.get("y", 0.0))
    tz = float(t.get("z", 0.0))

    rx = float(r.get("qx", 0.0))
    ry = float(r.get("qy", 0.0))
    rz = float(r.get("qz", 0.0))

    move_scale = scene.psm_move_scale
    rot_scale = scene.psm_rotation_scale
    smoothing_amount = scene.psm_smoothing
    blend = _smoothing_amount_to_blend(smoothing_amount)

    left_right_strength = getattr(scene, "psm_left_right_strength", 1.0)
    up_down_strength = getattr(scene, "psm_up_down_strength", 1.0)
    forward_back_strength = getattr(scene, "psm_forward_back_strength", 1.0)

    pitch_strength = getattr(scene, "psm_pitch_strength", 1.0)
    roll_strength = getattr(scene, "psm_roll_strength", 1.0)
    yaw_strength = getattr(scene, "psm_yaw_strength", 1.0)

    view_rotation = _find_reference_view_rotation()

    if _control_target_kind == "POSE_BONE":
        if obj.type != 'ARMATURE' or obj.mode != 'POSE':
            reset_control_state()
            return

        pbone = obj.pose.bones.get(_control_bone_name)
        if pbone is None:
            reset_control_state()
            return

        armature_rot = obj.matrix_world.to_quaternion()
        pose_view_rotation = armature_rot.inverted() @ view_rotation
        delta_pose_loc, delta_pose_rot = _build_view_relative_motion(
            tx, ty, tz, rx, ry, rz,
            move_scale, rot_scale,
            pose_view_rotation,
            left_right_strength, up_down_strength, forward_back_strength,
            pitch_strength, roll_strength, yaw_strength,
        )

        start_loc, start_rot, start_scale = _control_bone_start_matrix.decompose()
        current_loc, current_rot, _current_scale = pbone.matrix.decompose()

        target_loc = start_loc + delta_pose_loc
        target_rot = delta_pose_rot @ start_rot
        target_scale = start_scale

        new_loc = current_loc.lerp(target_loc, blend)
        new_rot = current_rot.slerp(target_rot, blend)

        smoothed_pose_matrix = Matrix.LocRotScale(new_loc, new_rot, target_scale)
        pbone.matrix_basis = _pose_matrix_to_basis_matrix(pbone, smoothed_pose_matrix)

        obj.update_tag()
        bpy.context.view_layer.update()

    else:
        current_matrix = obj.matrix_world.copy()
        current_loc = current_matrix.to_translation()
        current_rot = current_matrix.to_quaternion()

        delta_world_loc, delta_world_rot = _build_view_relative_motion(
            tx, ty, tz, rx, ry, rz,
            move_scale, rot_scale,
            view_rotation,
            left_right_strength, up_down_strength, forward_back_strength,
            pitch_strength, roll_strength, yaw_strength,
        )

        start_loc = _control_object_start_matrix.to_translation()
        start_rot = _control_object_start_matrix.to_quaternion()

        target_loc = start_loc + delta_world_loc
        target_rot = delta_world_rot @ start_rot

        new_loc = current_loc.lerp(target_loc, blend)
        new_rot = current_rot.slerp(target_rot, blend)

        new_matrix = new_rot.to_matrix().to_4x4()
        new_matrix.translation = new_loc
        obj.matrix_world = new_matrix
