import 'dart:async';
import 'package:flutter/material.dart';
import 'tcp_client.dart';
import 'protocol.dart';
import 'ar_pose_channel.dart';
import 'pose_math.dart';
import 'home_page.dart';

class ControlPage extends StatefulWidget {
  final TcpClient client;
  final String host;
  final int port;

  const ControlPage({
    super.key,
    required this.client,
    required this.host,
    required this.port,
  });

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  StreamSubscription<ArPose>? _poseSub;

  ArPose? _latestPose;
  ArPose? _neutralPose;

  bool _trackingStarted = false;
  bool _controlActive = false;
  bool _disconnecting = false;
  String _status = 'Connected';

  @override
  void initState() {
    super.initState();
    _startAr();
    _status = 'Connected to ${widget.host}:${widget.port}';
  }

  @override
  void dispose() {
    _poseSub?.cancel();
    ArPoseChannel.stopTracking();
    widget.client.disconnect();
    super.dispose();
  }

  Future<void> _startAr() async {
    try {
      await ArPoseChannel.startTracking();
      _poseSub = ArPoseChannel.poseStream().listen(_onPose);
      if (!mounted) return;
      setState(() {
        _trackingStarted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'AR start failed: $e';
      });
    }
  }

  double _applyDeadzone(double value, double deadzone) {
    return value.abs() < deadzone ? 0.0 : value;
  }

  void _onPose(ArPose pose) {
    _latestPose = pose;

    if (widget.client.isConnected && _controlActive && _neutralPose != null) {
      final delta = computeNeutralRelativeDelta(
        neutral: _neutralPose!,
        current: pose,
      );

      final rawT = delta.translationLocal;
      final rawEuler = delta.rotationDelta.toEulerXYZ();

      final tx = _applyDeadzone(rawT.x, 0.01);
      final ty = _applyDeadzone(rawT.y, 0.01);
      final tz = _applyDeadzone(rawT.z, 0.01);

      final rx = _applyDeadzone(rawEuler.x, 0.015);
      final ry = _applyDeadzone(rawEuler.y, 0.015);
      final rz = _applyDeadzone(rawEuler.z, 0.015);

      widget.client.send(controlInputMessage(
        active: true,
        tx: tx,
        ty: ty,
        tz: tz,
        qx: rx,
        qy: ry,
        qz: rz,
        qw: 1.0,
        tracking: pose.tracking,
      ));
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _controlStart() {
    if (_latestPose == null) return;

    setState(() {
      _controlActive = true;
      _neutralPose = _latestPose;
    });
  }

  void _controlEnd() {
    setState(() {
      _controlActive = false;
      _neutralPose = null;
    });

    if (widget.client.isConnected) {
      widget.client.send(controlInputMessage(
        active: false,
        tx: 0.0,
        ty: 0.0,
        tz: 0.0,
        qx: 0.0,
        qy: 0.0,
        qz: 0.0,
        qw: 1.0,
        tracking: _latestPose?.tracking ?? 'unknown',
      ));
    }
  }

  Future<void> _disconnectAndReturnHome() async {
    if (_disconnecting) return;

    setState(() {
      _disconnecting = true;
      _controlActive = false;
      _neutralPose = null;
    });

    try {
      if (widget.client.isConnected) {
        widget.client.send(controlInputMessage(
          active: false,
          tx: 0.0,
          ty: 0.0,
          tz: 0.0,
          qx: 0.0,
          qy: 0.0,
          qz: 0.0,
          qw: 1.0,
          tracking: _latestPose?.tracking ?? 'unknown',
        ));
      }
    } catch (_) {}

    await widget.client.disconnect();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pose = _latestPose;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hold to Control'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _disconnecting ? null : _disconnectAndReturnHome,
        ),
        actions: [
          TextButton(
            onPressed: _disconnecting ? null : _disconnectAndReturnHome,
            child: const Text('Disconnect'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Status: $_status'),
              Text('AR started: $_trackingStarted'),
              Text('Tracking: ${pose?.tracking ?? "none"}'),
              Text('Control Active: $_controlActive'),
              const SizedBox(height: 12),
              if (pose != null) ...[
                Text(
                  'Position: ${pose.px.toStringAsFixed(3)}, '
                  '${pose.py.toStringAsFixed(3)}, '
                  '${pose.pz.toStringAsFixed(3)}',
                ),
                Text(
                  'Rotation: ${pose.qx.toStringAsFixed(3)}, '
                  '${pose.qy.toStringAsFixed(3)}, '
                  '${pose.qz.toStringAsFixed(3)}, '
                  '${pose.qw.toStringAsFixed(3)}',
                ),
              ],
              const SizedBox(height: 24),
              GestureDetector(
                onTapDown: (_) => _controlStart(),
                onTapUp: (_) => _controlEnd(),
                onTapCancel: _controlEnd,
                child: Container(
                  width: 220,
                  height: 220,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _controlActive ? Colors.green : Colors.deepPurple,
                  ),
                  child: Text(
                    _controlActive ? 'Release to Stop' : 'Hold to Control',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select an object or pose control in Blender, then hold the button to drive it with the phone.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}