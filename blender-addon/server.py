# server.py

import socket
import threading
import json


class ControlServer:
    def __init__(self, host="0.0.0.0", port=5000):
        self.host = host
        self.port = port
        self.is_running = False

        self._sock = None
        self._thread = None
        self._incoming = []
        self._lock = threading.Lock()

    def start(self):
        if self.is_running:
            return

        self.is_running = True
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self):
        self.is_running = False
        if self._sock:
            try:
                self._sock.close()
            except Exception:
                pass
            self._sock = None

    def pop_incoming(self):
        with self._lock:
            msgs = self._incoming[:]
            self._incoming.clear()
            return msgs

    def _push_message(self, msg):
        with self._lock:
            self._incoming.append(msg)

    def _run(self):
        self._sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._sock.bind((self.host, self.port))
        self._sock.listen(1)
        self._sock.settimeout(1.0)

        while self.is_running:
            try:
                conn, addr = self._sock.accept()
                conn.settimeout(1.0)
                self._handle_client(conn)
            except socket.timeout:
                continue
            except OSError:
                break
            except Exception as e:
                print("Server error:", e)

    def _handle_client(self, conn):
        buffer = ""
        with conn:
            while self.is_running:
                try:
                    data = conn.recv(4096)
                    if not data:
                        break

                    buffer += data.decode("utf-8", errors="ignore")

                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        line = line.strip()
                        if not line:
                            continue
                        try:
                            msg = json.loads(line)
                            self._push_message(msg)
                        except json.JSONDecodeError:
                            print("Invalid JSON:", line)

                except socket.timeout:
                    continue
                except Exception as e:
                    print("Client error:", e)
                    break