import 'dart:async';
import 'package:flutter/services.dart';

class ArPose {
  final String tracking;
  final double px;
  final double py;
  final double pz;
  final double qx;
  final double qy;
  final double qz;
  final double qw;
  final double arQx;
  final double arQy;
  final double arQz;
  final double arQw;
  final double timestamp;

  const ArPose({
    required this.tracking,
    required this.px,
    required this.py,
    required this.pz,
    required this.qx,
    required this.qy,
    required this.qz,
    required this.qw,
    required this.arQx,
    required this.arQy,
    required this.arQz,
    required this.arQw,
    required this.timestamp,
  });

  factory ArPose.fromMap(Map<dynamic, dynamic> map) {
    return ArPose(
      tracking: (map['tracking'] ?? 'unknown').toString(),
      px: (map['px'] ?? 0.0).toDouble(),
      py: (map['py'] ?? 0.0).toDouble(),
      pz: (map['pz'] ?? 0.0).toDouble(),
      qx: (map['qx'] ?? 0.0).toDouble(),
      qy: (map['qy'] ?? 0.0).toDouble(),
      qz: (map['qz'] ?? 0.0).toDouble(),
      qw: (map['qw'] ?? 1.0).toDouble(),
      arQx: (map['ar_qx'] ?? 0.0).toDouble(),
      arQy: (map['ar_qy'] ?? 0.0).toDouble(),
      arQz: (map['ar_qz'] ?? 0.0).toDouble(),
      arQw: (map['ar_qw'] ?? 1.0).toDouble(),
      timestamp: (map['timestamp'] ?? 0.0).toDouble(),
    );
  }

  @override
  String toString() {
    return 'ArPose(tracking: $tracking, '
        'p=[$px, $py, $pz], '
        'q=[$qx, $qy, $qz, $qw], '
        'arq=[$arQx, $arQy, $arQz, $arQw], '
        't=$timestamp)';
  }
}

class ArPoseChannel {
  static const MethodChannel _method =
      MethodChannel('phone_spatial_mouse/ar_method');

  static const EventChannel _events =
      EventChannel('phone_spatial_mouse/ar_pose_stream');

  static Future<void> startTracking() async {
    await _method.invokeMethod('startTracking');
  }

  static Future<void> stopTracking() async {
    await _method.invokeMethod('stopTracking');
  }

  static Stream<ArPose> poseStream() {
    return _events.receiveBroadcastStream().map((event) {
      return ArPose.fromMap(event as Map<dynamic, dynamic>);
    });
  }
}
