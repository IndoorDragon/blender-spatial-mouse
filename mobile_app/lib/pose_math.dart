import 'dart:math' as math;
import 'ar_pose_channel.dart';

class Vec3 {
  final double x;
  final double y;
  final double z;

  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);
  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

class Quat {
  final double x;
  final double y;
  final double z;
  final double w;

  const Quat(this.x, this.y, this.z, this.w);

  Quat normalized() {
    final mag = math.sqrt(x * x + y * y + z * z + w * w);
    if (mag == 0) return const Quat(0, 0, 0, 1);
    return Quat(x / mag, y / mag, z / mag, w / mag);
  }

  Quat inverse() {
    final n = x * x + y * y + z * z + w * w;
    if (n == 0) return const Quat(0, 0, 0, 1);
    return Quat(-x / n, -y / n, -z / n, w / n);
  }

  Quat multiply(Quat b) {
    final a = this;
    return Quat(
      a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
      a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
      a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
      a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
    );
  }

  Vec3 rotateVector(Vec3 v) {
    final qv = Quat(v.x, v.y, v.z, 0.0);
    final result = multiply(qv).multiply(inverse());
    return Vec3(result.x, result.y, result.z);
  }

  // Returns Euler angles in radians:
  // x = pitch
  // y = roll
  // z = yaw
  Vec3 toEulerXYZ() {
    final q = normalized();

    final sinrCosp = 2.0 * (q.w * q.x + q.y * q.z);
    final cosrCosp = 1.0 - 2.0 * (q.x * q.x + q.y * q.y);
    final pitch = math.atan2(sinrCosp, cosrCosp);

    final sinp = 2.0 * (q.w * q.y - q.z * q.x);
    final roll = sinp.abs() >= 1.0
        ? (sinp >= 0 ? math.pi / 2 : -math.pi / 2)
        : math.asin(sinp);

    final sinyCosp = 2.0 * (q.w * q.z + q.x * q.y);
    final cosyCosp = 1.0 - 2.0 * (q.y * q.y + q.z * q.z);
    final yaw = math.atan2(sinyCosp, cosyCosp);

    return Vec3(pitch, roll, yaw);
  }

  @override
  String toString() => 'Quat($x, $y, $z, $w)';
}

class PoseDelta {
  final Vec3 translationLocal;
  final Quat rotationDelta;

  const PoseDelta({
    required this.translationLocal,
    required this.rotationDelta,
  });
}

Quat quatFromPose(ArPose p) => Quat(p.qx, p.qy, p.qz, p.qw).normalized();
Quat arQuatFromPose(ArPose p) => Quat(p.arQx, p.arQy, p.arQz, p.arQw).normalized();
Vec3 vecFromPose(ArPose p) => Vec3(p.px, p.py, p.pz);

PoseDelta computeNeutralRelativeDelta({
  required ArPose neutral,
  required ArPose current,
}) {
  final qNeutralMotion = quatFromPose(neutral);
  final qCurrentMotion = quatFromPose(current);

  final qNeutralAr = arQuatFromPose(neutral);

  final pNeutral = vecFromPose(neutral);
  final pCurrent = vecFromPose(current);

  // Rotation delta still comes from Core Motion because it gave better rotational behavior.
  final qDelta = qNeutralMotion.inverse().multiply(qCurrentMotion).normalized();

  // Translation MUST be converted using the SAME coordinate frame that produced ARKit's
  // world-space camera positions. Otherwise forward/back/left/right can look random.
  final worldDelta = pCurrent - pNeutral;
  final localDelta = qNeutralAr.inverse().rotateVector(worldDelta);

  return PoseDelta(
    translationLocal: localDelta,
    rotationDelta: qDelta,
  );
}
