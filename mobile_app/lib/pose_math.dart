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

  static const identity = Quat(0.0, 0.0, 0.0, 1.0);

  Quat normalized() {
    final mag = math.sqrt(x * x + y * y + z * z + w * w);
    if (mag == 0) return identity;
    return Quat(x / mag, y / mag, z / mag, w / mag);
  }

  Quat inverse() {
    final n = x * x + y * y + z * z + w * w;
    if (n == 0) return identity;
    return Quat(-x / n, -y / n, -z / n, w / n);
  }

  Quat negate() => Quat(-x, -y, -z, -w);

  double dot(Quat other) {
    return x * other.x + y * other.y + z * other.z + w * other.w;
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

  Quat canonicalized() {
    final q = normalized();
    return q.w < 0.0 ? q.negate() : q;
  }

  Quat shortestArcFrom(Quat reference) {
    final q = normalized();
    return reference.dot(q) < 0.0 ? q.negate() : q;
  }

  double angleRadians() {
    final q = canonicalized();
    final clampedW = q.w.clamp(-1.0, 1.0);
    return 2.0 * math.acos(clampedW);
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
Quat arQuatFromPose(ArPose p) =>
    Quat(p.arQx, p.arQy, p.arQz, p.arQw).normalized();
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

  // Use Core Motion for rotation delta, but keep it as a quaternion all the way
  // through so we avoid Euler discontinuities near 180 degrees.
  final qDelta = qNeutralMotion
      .inverse()
      .multiply(qCurrentMotion)
      .canonicalized();

  // Translation remains relative to the neutral AR frame.
  final worldDelta = pCurrent - pNeutral;
  final localDelta = qNeutralAr.inverse().rotateVector(worldDelta);

  return PoseDelta(
    translationLocal: localDelta,
    rotationDelta: qDelta,
  );
}