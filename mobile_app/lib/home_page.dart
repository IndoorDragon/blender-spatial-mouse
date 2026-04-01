import 'package:flutter/material.dart';
import 'tcp_client.dart';
import 'protocol.dart';
import 'control_page.dart';
import 'qr_scan_page.dart';

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

  bool _showManual = false;
  bool _isConnecting = false;
  bool _handoffClient = false;
  String _status = 'Not connected';

  @override
  void dispose() {
    if (!_handoffClient) {
      _client.disconnect();
    }
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connectTo(String host, int port) async {
    setState(() {
      _isConnecting = true;
      _status = 'Connecting to $host:$port...';
    });

    try {
      await _client.connect(host, port);
      _client.send(helloMessage());
      _client.send(setModeMessage());

      if (!mounted) return;

      _handoffClient = true;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ControlPage(
            client: _client,
            host: host,
            port: port,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _status = 'Connect failed: $e';
      });
    }
  }

  Future<void> _connectManual() async {
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();

    final port = int.tryParse(portText);
    if (host.isEmpty || port == null) {
      setState(() {
        _status = 'Please enter a valid host and port';
      });
      return;
    }

    await _connectTo(host, port);
  }

  Future<void> _scanQrAndConnect() async {
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );

    if (!mounted || payload == null || payload.trim().isEmpty) {
      return;
    }

    try {
      final target = TcpClient.parseConnectionPayload(payload);
      await _connectTo(target.host, target.port);
    } catch (e) {
      setState(() {
        _status = 'Invalid QR code: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blender Spatial Mouse'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Icon(
                Icons.control_camera,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Connect to Blender',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how you want to connect your phone to the Blender add-on.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isConnecting ? null : _scanQrAndConnect,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Code'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _isConnecting
                      ? null
                      : () {
                          setState(() {
                            _showManual = !_showManual;
                          });
                        },
                  icon: const Icon(Icons.language),
                  label: const Text('Manual IP Address'),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: _showManual
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: 'Blender Host',
                            hintText: '10.0.0.217',
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: 'Control Port',
                            hintText: '5000',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isConnecting ? null : _connectManual,
                            child: const Text('Connect'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                secondChild: const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              Text(
                'Status: $_status',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}