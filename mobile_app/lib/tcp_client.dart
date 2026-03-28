import 'dart:io';
import 'dart:convert';

class TcpClient {
  Socket? _socket;

  bool get isConnected => _socket != null;

  Future<void> connect(String host, int port) async {
    _socket = await Socket.connect(host, port);
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