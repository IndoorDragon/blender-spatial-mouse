import 'dart:io';

class ConnectionTarget {
  final String host;
  final int port;

  const ConnectionTarget({
    required this.host,
    required this.port,
  });
}

class TcpClient {
  Socket? _socket;

  bool get isConnected => _socket != null;

  Future<void> connect(String host, int port) async {
    _socket = await Socket.connect(host, port);
  }

  static ConnectionTarget parseConnectionPayload(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      throw const FormatException('Empty QR payload');
    }

    if (value.contains('://')) {
      final uri = Uri.parse(value);
      final host = uri.host.trim();
      final port = uri.port;

      if (host.isEmpty || port <= 0) {
        throw FormatException('Invalid connection payload: $value');
      }

      return ConnectionTarget(host: host, port: port);
    }

    final parts = value.split(':');
    if (parts.length != 2) {
      throw FormatException('Expected host:port, got: $value');
    }

    final host = parts[0].trim();
    final port = int.tryParse(parts[1].trim());

    if (host.isEmpty || port == null || port <= 0) {
      throw FormatException('Invalid host or port in payload: $value');
    }

    return ConnectionTarget(host: host, port: port);
  }

  void send(String message) {
    _socket?.write(message);
  }

  Future<void> disconnect() async {
    await _socket?.flush();
    await _socket?.close();
    _socket = null;
  }
}