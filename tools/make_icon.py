"""Draws the Kids Time Control icon (a clock) into a multi-size .ico.

Usage: python3 tools/make_icon.py OUT.ico
No dependencies: 32-bit BMP entries with alpha, antialiased by supersampling.
"""
import math
import struct
import sys

BACKGROUND = (0x3F, 0x51, 0xB5)  # indigo
FACE = (0xFF, 0xFF, 0xFF)


def dist_to_segment(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def sample(x, y):
    """Color and alpha at (x, y) in a unit square."""
    r = math.hypot(x - 0.5, y - 0.5)
    if r > 0.48:
        return None
    hands = [((0.5, 0.5), (0.5, 0.2), 0.055), ((0.5, 0.5), (0.72, 0.62), 0.055)]
    for (ax, ay), (bx, by), width in hands:
        if dist_to_segment(x, y, ax, ay, bx, by) < width:
            return FACE
    if 0.36 < r < 0.42:
        return FACE
    return BACKGROUND


def render(size, ss=4):
    pixels = []
    for row in range(size):
        line = []
        for col in range(size):
            acc = [0, 0, 0]
            hits = 0
            for sy in range(ss):
                for sx in range(ss):
                    color = sample((col + (sx + 0.5) / ss) / size, (row + (sy + 0.5) / ss) / size)
                    if color:
                        hits += 1
                        for i in range(3):
                            acc[i] += color[i]
            alpha = round(255 * hits / (ss * ss))
            rgb = [round(c / hits) if hits else 0 for c in acc]
            line.append((rgb[0], rgb[1], rgb[2], alpha))
        pixels.append(line)
    return pixels


def bmp_entry(size):
    pixels = render(size)
    header = struct.pack('<IiiHHIIiiII', 40, size, size * 2, 1, 32, 0, 0, 0, 0, 0, 0)
    xor = b''.join(
        struct.pack('BBBB', b, g, r, a) for line in reversed(pixels) for (r, g, b, a) in line
    )
    mask_row = ((size + 31) // 32) * 4
    and_mask = b'\x00' * (mask_row * size)
    return header + xor + and_mask


def main(out):
    sizes = [16, 20, 24, 32, 48, 64, 256]
    entries = [bmp_entry(s) for s in sizes]
    data = struct.pack('<HHH', 0, 1, len(sizes))
    offset = 6 + 16 * len(sizes)
    for size, entry in zip(sizes, entries):
        dim = 0 if size == 256 else size
        data += struct.pack('<BBBBHHII', dim, dim, 0, 0, 1, 32, len(entry), offset)
        offset += len(entry)
    data += b''.join(entries)
    with open(out, 'wb') as file:
        file.write(data)


if __name__ == '__main__':
    main(sys.argv[1])
