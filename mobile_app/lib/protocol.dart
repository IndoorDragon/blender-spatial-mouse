import 'dart:convert';

String helloMessage() {
  return jsonEncode({
    "type": "hello",
    "app": "blender_spatial_mouse",
    "version": 2,
  }) + "\n";
}

String setModeMessage() {
  return jsonEncode({
    "type": "set_mode",
    "mode": "spatial_mouse",
  }) + "\n";
}

String controlInputMessage({
  required bool active,
  required double tx,
  required double ty,
  required double tz,
  required double qx,
  required double qy,
  required double qz,
  required double qw,
  required String tracking,
}) {
  return jsonEncode({
    "type": "control_input",
    "active": active,
    "tracking": tracking,
    "translation": {
      "x": tx,
      "y": ty,
      "z": tz,
    },
    "rotation": {
      "mode": "quaternion_delta",
      "qx": qx,
      "qy": qy,
      "qz": qz,
      "qw": qw,
    }
  }) + "\n";
}