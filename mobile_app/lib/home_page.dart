import 'dart:async';
import 'package:flutter/material.dart';
import 'tcp_client.dart';
import 'protocol.dart';
import 'ar_pose_channel.dart';
import 'pose_math.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TcpClient _client = TcpClient();

  final TextEditingController _hostController =
      TextEditingController(text: '192.168.1.100');
  final TextEditingController _portController =
      TextEditingController(text: '5000');

  StreamSubscription<ArPose>? _poseSub;

  ArPose? _latestPose;
  ArPose? _neutralPose;

  bool _trackingStarted = false;
  bool _controlActive = false;
  String _status = 'Disconnected';

  @override
  void initState() {
    super.initState();
    _startAr();
  }

  @override
  void dispose() {
    _poseSub?.cancel();
    ArPoseChannel.stopTracking();
    _client.disconnect();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _startAr() async {
    try {
      await ArPoseChannel.startTracking();
      _poseSub = ArPoseChannel.poseStream().listen(_onPose);
      setState(() {
        _trackingStarted = true;
      });
    } catch (e) {
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

    if (_client.isConnected && _controlActive && _neutralPose != null) {
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

      _client.send(controlInputMessage(
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

  Future<void> _connect() async {
    try {
      final host = _hostController.text.trim();
      final port = int.parse(_portController.text.trim());

      await _client.connect(host, port);
      _client.send(helloMessage());
      _client.send(setModeMessage());

      setState(() {
        _status = 'Connected';
      });
    } catch (e) {
      setState(() {
        _status = 'Connect failed: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    await _client.disconnect();
    setState(() {
      _status = 'Disconnected';
      _controlActive = false;
      _neutralPose = null;
    });
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

    if (_client.isConnected) {
      _client.send(controlInputMessage(
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

  @override
  Widget build(BuildContext context) {
    final pose = _latestPose;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blender Spatial Mouse'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(labelText: 'Blender Host'),
              ),
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Control Port'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _client.isConnected ? null : _connect,
                      child: const Text('Connect'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _client.isConnected ? _disconnect : null,
                      child: const Text('Disconnect'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Status: $_status'),
              Text('AR started: $_trackingStarted'),
              Text('Tracking: ${pose?.tracking ?? "none"}'),
              Text('Control Active: $_controlActive'),
              const SizedBox(height: 12),
              if (pose != null) ...[
                Text('Position: ${pose.px.toStringAsFixed(3)}, '
                    '${pose.py.toStringAsFixed(3)}, '
                    '${pose.pz.toStringAsFixed(3)}'),
                Text('Rotation: ${pose.qx.toStringAsFixed(3)}, '
                    '${pose.qy.toStringAsFixed(3)}, '
                    '${pose.qz.toStringAsFixed(3)}, '
                    '${pose.qw.toStringAsFixed(3)}'),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
