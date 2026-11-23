"""Convert a frame written by render_frame.v (plain PPM, 2 bits per colour)
to a PNG, using only Python's standard library.

    python3 ppm_to_png.py frame_1.ppm frame_1.png
"""

import struct
import sys
import zlib


def read_ppm(path):
    words = open(path).read().split()
    assert words[0] == "P3", "not a plain PPM"
    width, height, maxval = int(words[1]), int(words[2]), int(words[3])
    values = [int(v) * 255 // maxval for v in words[4:]]
    assert len(values) == width * height * 3, "PPM is short"
    return width, height, bytes(values)


def write_png(path, width, height, rgb):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    stride = width * 3
    raw = b"".join(b"\0" + rgb[y * stride:(y + 1) * stride] for y in range(height))
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


if __name__ == "__main__":
    write_png(sys.argv[2], *read_ppm(sys.argv[1]))
