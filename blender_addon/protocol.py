MSG_HELLO = "hello"
MSG_SET_MODE = "set_mode"
MSG_CONTROL_INPUT = "control_input"

MODE_SPATIAL_MOUSE = "spatial_mouse"


def parse_message(raw):
    if not isinstance(raw, dict):
        return None

    msg_type = raw.get("type")
    if not isinstance(msg_type, str):
        return None

    return raw
