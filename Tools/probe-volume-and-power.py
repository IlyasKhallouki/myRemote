#!/usr/bin/env python3
"""Find out which volume and power messages your TV actually accepts.

The app can already read the TV's volume level and maximum, because the TV
pushes them. What it cannot know without asking is whether the same message
works in the other direction -- as a command -- or which power keycode this
panel honours. Both are guesses in the app today, behind off-by-default
switches; this settles them.

Run it with the TV on and the app closed, so nothing competes for the session:

    cd .protocol-probe && ./.venv/bin/python ../Tools/probe-volume-and-power.py 192.168.1.42

It connects with the same client.p12 you paired with, prints the volume the TV
reports, then tries one candidate at a time and tells you whether the reported
level moved. Nothing here writes to the app's settings -- you read the result
and set the switches yourself.
"""

import argparse
import pathlib
import socket
import ssl
import struct
import sys
import time

PORT = 6466
CERT = pathlib.Path(__file__).resolve().parent.parent / ".protocol-probe" / "cert.pem"
KEY = pathlib.Path(__file__).resolve().parent.parent / ".protocol-probe" / "key.pem"

# Field numbers, matching Sources/TVRemote/Protocol/RemoteCodec.swift.
F_CONFIGURE, F_SET_ACTIVE, F_PING_REQ, F_PING_RES = 1, 2, 8, 9
F_KEY_INJECT, F_START, F_SET_VOLUME = 10, 40, 50


def varint(value: int) -> bytes:
    out = bytearray()
    while True:
        byte = value & 0x7F
        value >>= 7
        out.append(byte | (0x80 if value else 0))
        if not value:
            return bytes(out)


def field(number: int, payload: bytes) -> bytes:
    return varint(number << 3 | 2) + varint(len(payload)) + payload


def varint_field(number: int, value: int) -> bytes:
    return varint(number << 3) + varint(value)


def framed(payload: bytes) -> bytes:
    return varint(len(payload)) + payload


def read_varint(data: bytes, at: int):
    shift = result = 0
    while at < len(data):
        byte = data[at]
        result |= (byte & 0x7F) << shift
        at += 1
        if not byte & 0x80:
            return result, at
        shift += 7
    return None, at


def parse_volume(frame: bytes):
    """Pull level/max out of a set-volume message, ignoring everything else."""
    at = 0
    while at < len(frame):
        tag, at = read_varint(frame, at)
        if tag is None:
            return None
        number, wire = tag >> 3, tag & 7
        if wire == 2:
            length, at = read_varint(frame, at)
            body = frame[at:at + length]
            at += length
            if number == F_SET_VOLUME:
                inner, level, maximum = 0, None, None
                while inner < len(body):
                    itag, inner = read_varint(body, inner)
                    if itag is None:
                        break
                    inum, iwire = itag >> 3, itag & 7
                    if iwire == 0:
                        value, inner = read_varint(body, inner)
                        if inum == 6:
                            maximum = value
                        elif inum == 7:
                            level = value
                    elif iwire == 2:
                        ilen, inner = read_varint(body, inner)
                        inner += ilen
                    else:
                        break
                if level is not None:
                    return level, maximum
        elif wire == 0:
            _, at = read_varint(frame, at)
        else:
            return None
    return None


class Session:
    def __init__(self, host):
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        context.load_cert_chain(CERT, KEY)
        raw = socket.create_connection((host, PORT), timeout=10)
        self.sock = context.wrap_socket(raw, server_hostname=host)
        self.buffer = b""
        self.volume = None

    def send(self, payload):
        self.sock.send(framed(payload))

    def pump(self, seconds=1.0):
        """Read frames for a while, answering the handshake so we stay alive."""
        deadline = time.time() + seconds
        self.sock.settimeout(0.3)
        while time.time() < deadline:
            try:
                chunk = self.sock.recv(8192)
            except (socket.timeout, TimeoutError):
                continue
            if not chunk:
                raise ConnectionError("the TV closed the session")
            self.buffer += chunk
            while True:
                length, offset = read_varint(self.buffer, 0)
                if length is None or len(self.buffer) < offset + length:
                    break
                frame = self.buffer[offset:offset + length]
                self.buffer = self.buffer[offset + length:]
                self.handle(frame)

    def handle(self, frame):
        volume = parse_volume(frame)
        if volume:
            self.volume = volume
        at = 0
        tag, at = read_varint(frame, at)
        if tag is None:
            return
        number = tag >> 3
        if number == F_CONFIGURE:
            device = (varint_field(3, 1) + field(4, b"1")
                      + field(5, b"probe") + field(6, b"1.0.0"))
            self.send(field(F_CONFIGURE, varint_field(1, 0b1001101011) + field(2, device)))
        elif number == F_SET_ACTIVE:
            self.send(field(F_SET_ACTIVE, varint_field(1, 0b1001101011)))
        elif number == F_PING_REQ:
            length, offset = read_varint(frame, 1)
            value, _ = read_varint(frame, offset + 1)
            self.send(field(F_PING_RES, varint_field(1, value or 0)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("host", help="the TV's IP address")
    parser.add_argument("--skip-power", action="store_true",
                        help="do not test power keycodes (they turn the TV off)")
    args = parser.parse_args()

    if not CERT.exists() or not KEY.exists():
        sys.exit(f"missing {CERT} / {KEY} -- pair first with .protocol-probe/pair.py")

    session = Session(args.host)
    print("connecting...")
    session.pump(4)
    if not session.volume:
        sys.exit("the TV never reported a volume; nudge it with the real remote and retry")

    level, maximum = session.volume
    print(f"TV reports volume {level} of {maximum}\n")

    # Aim somewhere clearly different from where we are, so a change is obvious.
    target = 2 if level > 4 else min(maximum or 20, 10)

    candidates = [
        ("field 50 / subfield 7 (mirrors the report; what the app sends today)",
         field(F_SET_VOLUME, varint_field(7, target))),
        ("field 50 / subfield 1",
         field(F_SET_VOLUME, varint_field(1, target))),
        ("field 50 / subfields 6+7 (max and level together)",
         field(F_SET_VOLUME, varint_field(6, maximum or 0) + varint_field(7, target))),
    ]

    for description, payload in candidates:
        print(f"trying {description} -> {target}")
        before = session.volume
        session.send(payload)
        session.pump(2)
        after = session.volume
        if after != before:
            print(f"  WORKED: volume moved {before} -> {after}")
            print("  Turn on Settings > Experimental > Absolute volume.\n")
            break
        print("  no change\n")
    else:
        print("None of the candidates moved the volume. Absolute volume is not")
        print("supported on this panel; leave the switch off and keep stepping.\n")

    if args.skip_power:
        return

    print("testing power keycodes -- the TV may switch off, that is the point")
    for name, code in [("KEYCODE_POWER (26)", 26), ("KEYCODE_TV_POWER (177)", 177)]:
        print(f"  sending {name}")
        session.send(field(F_KEY_INJECT, varint_field(1, code) + varint_field(2, 3)))
        session.pump(3)
        answer = input("  did the TV react? [y/N] ").strip().lower()
        if answer == "y":
            print(f"  {name} works -- keycode {code}")
            print("  Turn on Settings > Lock Screen > Power key.")
            return
    print("  neither keycode did anything")


if __name__ == "__main__":
    main()
