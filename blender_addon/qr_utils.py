import os
import socket
import segno
import bpy


def get_best_lan_ip() -> str:
    test_sock = None
    try:
        test_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        test_sock.connect(("8.8.8.8", 80))
        ip = test_sock.getsockname()[0]
        if ip:
            return ip
    except Exception:
        pass
    finally:
        if test_sock is not None:
            try:
                test_sock.close()
            except Exception:
                pass

    try:
        hostname = socket.gethostname()
        ip = socket.gethostbyname(hostname)
        if ip and not ip.startswith("127."):
            return ip
    except Exception:
        pass

    return "127.0.0.1"


def _qr_matrix_to_pixels(qr, scale=8, border=4):
    matrix = list(qr.matrix)
    h = len(matrix)
    w = len(matrix[0]) if h else 0

    img_w = (w + border * 2) * scale
    img_h = (h + border * 2) * scale

    white = (1.0, 1.0, 1.0, 1.0)
    black = (0.0, 0.0, 0.0, 1.0)

    pixels = [1.0] * (img_w * img_h * 4)

    for y in range(img_h):
        for x in range(img_w):
            qr_x = x // scale - border
            qr_y = y // scale - border

            is_dark = False
            if 0 <= qr_x < w and 0 <= qr_y < h:
                is_dark = bool(matrix[qr_y][qr_x])

            color = black if is_dark else white
            idx = (y * img_w + x) * 4
            pixels[idx:idx+4] = color

    return img_w, img_h, pixels


def generate_qr_png(data: str, filepath: str, image_name="PSM_QR_Code"):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)

    qr = segno.make(data)
    width, height, pixels = _qr_matrix_to_pixels(qr, scale=8, border=4)

    existing = bpy.data.images.get(image_name)
    if existing is not None:
        bpy.data.images.remove(existing)

    image = bpy.data.images.new(image_name, width=width, height=height, alpha=True)
    image.pixels[:] = pixels
    image.filepath_raw = filepath
    image.file_format = 'PNG'
    image.save()

    return filepath


def generate_connection_qr(host: str, port: int, folder: str):
    # IMPORTANT:
    # Your current server.py is a raw TCP socket server, not a WebSocket server.
    # So tcp:// is more honest than ws:// for now.
    payload = f"tcp://{host}:{port}"

    png_path = os.path.join(folder, "connection_qr.png")
    generate_qr_png(payload, png_path)

    return png_path, payload