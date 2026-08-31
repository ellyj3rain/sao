#!/usr/bin/env python3
r"""[B51] The mod's icon and poster, derived rather than authored.

Border 19 has reported `no icon, poster` on every run of the gate since
the day it was written. In a load order of two hundred and thirty-four
mods this one shows as a blank tile with a name beside it.

WHY GENERATE INSTEAD OF DRAW
----------------------------
Because a binary nobody can regenerate is a binary nobody can check.
Every other shipped thing in this tree has a border that can tell
whether it still says what it is supposed to say; a PNG dropped in by
hand has none, and the first time somebody opens it in an editor and
saves it back, nothing will notice.

This writes both files from arithmetic, with no image library - PNG is
a signature, an IHDR, one zlib-compressed IDAT of filtered scanlines,
and an IEND. Border 73 regenerates and compares bytes, so the art is a
derived artifact like everything else here rather than an asset that
happens to be in the repository.

THE SUBJECT
-----------
An eye, because the mod's first claim is that what a survivor knows
comes from what they have seen. Its iris is a constellation, because
the second claim is that they are a county rather than a crowd - the
same shape at 32 pixels and at 870.

Usage: make_art.py [--check <dir>]  (writes, or renders to a temp dir)
"""
import math
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
MOD = ROOT / "mod"
VERSIONED = MOD / "42.20"

# The county at night: a cold ground, a warm iris, one bright pupil.
GROUND = (0x14, 0x18, 0x1D)
SCLERA = (0x22, 0x2A, 0x33)
RIM = (0x5A, 0x6B, 0x7A)
IRIS_IN = (0xE8, 0xA3, 0x3D)
IRIS_OUT = (0x9A, 0x5E, 0x1E)
PUPIL = (0x0B, 0x0E, 0x12)
STAR = (0xFF, 0xF1, 0xD6)
EDGE = (0x46, 0x55, 0x63)
TEXT = (0xD8, 0xDE, 0xE4)
DIM = (0x76, 0x83, 0x90)

# Where the survivors sit inside the iris, in iris radii. Fixed rather
# than random: the art has to be the same bytes every time it is
# generated or Border 73 is checking nothing.
CONSTELLATION = tuple(
    (math.cos(math.radians(a)) * r, math.sin(math.radians(a)) * r)
    for a, r in ((-72, 0.70), (-18, 0.76), (38, 0.66), (96, 0.74),
                 (152, 0.68), (214, 0.77), (268, 0.64)))
# Neighbours around the ring, and two chords across it - a county is
# not a wheel and it is not a circle of strangers either.
LINKS = ((0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 0),
         (0, 3), (2, 5))

# A 5x7 face for the poster's two lines. Only the characters those
# lines use; a missing one is a blank, which would be visible.
FONT = {
    "A": ("01110", "10001", "10001", "11111", "10001", "10001", "10001"),
    "C": ("01111", "10000", "10000", "10000", "10000", "10000", "01111"),
    "D": ("11110", "10001", "10001", "10001", "10001", "10001", "11110"),
    "E": ("11111", "10000", "10000", "11110", "10000", "10000", "11111"),
    "H": ("10001", "10001", "10001", "11111", "10001", "10001", "10001"),
    "I": ("11111", "00100", "00100", "00100", "00100", "00100", "11111"),
    "L": ("10000", "10000", "10000", "10000", "10000", "10000", "11111"),
    "N": ("10001", "11001", "10101", "10011", "10001", "10001", "10001"),
    "O": ("01110", "10001", "10001", "10001", "10001", "10001", "01110"),
    "P": ("11110", "10001", "10001", "11110", "10000", "10000", "10000"),
    "R": ("11110", "10001", "10001", "11110", "10100", "10010", "10001"),
    "S": ("01111", "10000", "10000", "01110", "00001", "00001", "11110"),
    "T": ("11111", "00100", "00100", "00100", "00100", "00100", "00100"),
    "U": ("10001", "10001", "10001", "10001", "10001", "10001", "01110"),
    "V": ("10001", "10001", "10001", "10001", "10001", "01010", "00100"),
    "W": ("10001", "10001", "10001", "10101", "10101", "11011", "10001"),
    "Y": ("10001", "10001", "01010", "00100", "00100", "00100", "00100"),
    " ": ("00000", "00000", "00000", "00000", "00000", "00000", "00000"),
}


class Canvas:
    def __init__(self, w, h, fill):
        self.w, self.h = w, h
        self.px = [list(fill) for _ in range(w * h)]

    def blend(self, x, y, colour, alpha):
        """Coverage-weighted paint. Antialiasing IS the design here -
        at 32 pixels a hard-edged circle is a polygon."""
        if alpha <= 0 or x < 0 or y < 0 or x >= self.w or y >= self.h:
            return
        alpha = min(1.0, alpha)
        p = self.px[y * self.w + x]
        for i in range(3):
            p[i] = int(round(p[i] + (colour[i] - p[i]) * alpha))

    def png(self):
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)
            for x in range(self.w):
                raw.extend(self.px[y * self.w + x])
        out = bytearray(b"\x89PNG\r\n\x1a\n")
        for tag, body in (
                (b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 2,
                                      0, 0, 0)),
                (b"IDAT", zlib.compress(bytes(raw), 9)),
                (b"IEND", b"")):
            out += struct.pack(">I", len(body)) + tag + body
            out += struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)
        return bytes(out)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def disc(c, cx, cy, r, colour, feather=1.0):
    lo, hi = int(cx - r - 2), int(cx + r + 2)
    for y in range(int(cy - r - 2), int(cy + r + 2) + 1):
        for x in range(lo, hi + 1):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            c.blend(x, y, colour, min(1.0, (r - d) / feather + 0.5))


def line(c, x0, y0, x1, y1, colour, width, alpha=1.0):
    steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 3) + 2
    for i in range(steps + 1):
        t = i / steps
        disc(c, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, width / 2.0,
             colour, feather=1.0)
    if alpha < 1.0:
        pass


def eye(c, cx, cy, half_w, half_h, iris_r, stars, rim_w, county=True):
    """A lens - the region inside both of two circles - then the iris.

    The lens is where the eye shape comes from: two circles of radius
    `R` whose centres sit `2*off` apart vertically overlap in exactly
    the almond every eye is drawn as. Solving for the circle that
    passes through the corners and the lids is one line of algebra and
    saves hand-plotting a curve that would then only be right at one
    size.
    """
    r = (half_w * half_w + half_h * half_h) / (2.0 * half_h)
    off = r - half_h
    for y in range(int(cy - half_h - 3), int(cy + half_h + 4)):
        for x in range(int(cx - half_w - 3), int(cx + half_w + 4)):
            px, py = x + 0.5 - cx, y + 0.5 - cy
            d = max(math.hypot(px, py + off), math.hypot(px, py - off))
            inside = (r - d)
            if inside > rim_w:
                shade = min(1.0, max(0.0, (py / half_h + 1.0) * 0.5))
                c.blend(x, y, mix(SCLERA, GROUND, shade * 0.55), 1.0)
            elif inside > -0.6:
                c.blend(x, y, RIM, min(1.0, (inside + 0.6) / 0.9))

    for y in range(int(cy - iris_r - 2), int(cy + iris_r + 3)):
        for x in range(int(cx - iris_r - 2), int(cx + iris_r + 3)):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= iris_r + 1:
                c.blend(x, y, mix(IRIS_IN, IRIS_OUT, min(1.0, d / iris_r)),
                        min(1.0, iris_r - d + 0.5))

    if not county:
        # At 32 pixels the iris is five across. Seven nodes and nine
        # edges inside it is not a drawing of a county, it is noise -
        # rendered and looked at, which is the only way that is ever
        # obvious. The tile gets the eye and nothing else.
        disc(c, cx, cy, iris_r * 0.46, PUPIL)
        disc(c, cx - iris_r * 0.34, cy - iris_r * 0.36, iris_r * 0.15, STAR)
        return
    disc(c, cx, cy, iris_r * 0.36, PUPIL)
    pts = [(cx + dx * iris_r, cy + dy * iris_r) for dx, dy in CONSTELLATION]
    for a, b in LINKS:
        line(c, pts[a][0], pts[a][1], pts[b][0], pts[b][1], EDGE,
             max(0.85, iris_r * 0.045))
    for x, y in pts:
        disc(c, x, y, stars, STAR)


def word(c, text, x, y, scale, colour, gap=1):
    for ch in text:
        if ch not in FONT:
            raise KeyError(
                "no glyph for " + repr(ch) + " - the first draft fell back "
                "to a blank, which is a character that silently is not "
                "there rather than an error anybody would see")
        glyph = FONT[ch]
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit == "1":
                    for sy in range(scale):
                        for sx in range(scale):
                            c.blend(x + gx * scale + sx, y + gy * scale + sy,
                                    colour, 1.0)
        x += (5 + gap) * scale
    return x


def text_width(text, scale, gap=1):
    return len(text) * (5 + gap) * scale - gap * scale


def icon():
    c = Canvas(32, 32, GROUND)
    eye(c, 16.0, 16.0, 14.5, 8.6, 6.4, 0.0, 1.2, county=False)
    return c.png()


def poster():
    w, h = 870, 1080
    c = Canvas(w, h, GROUND)
    # The county behind the eye: a fixed scatter, dimmer toward the
    # edges, so the ground is not flat black.
    seed = 20260828
    for i in range(150):
        seed = (seed * 1103515245 + 12345) % 2147483648
        px = seed % w
        seed = (seed * 1103515245 + 12345) % 2147483648
        py = seed % h
        d = math.hypot(px - w / 2.0, py - h * 0.40) / (w * 0.75)
        disc(c, px, py, 1.6, mix(EDGE, GROUND, min(1.0, d)), feather=1.4)

    eye(c, w / 2.0, h * 0.355, 330.0, 196.0, 132.0, 7.0, 5.0)

    # The first draft set the title at scale 11 and it ran 318 pixels
    # off both edges - `SURVIVOR AWARENESS` is eighteen characters and
    # eighteen characters do not fit on 870 at any size worth reading.
    # Two lines, and the scale is derived from the widest of them
    # against the margin rather than chosen and hoped for.
    margin = 0.86
    lines = (("SURVIVOR", TEXT), ("AWARENESS", TEXT))
    scale = min(int(w * margin) // ((5 + 1) * max(len(t) for t, _ in lines)),
                14)
    y = int(h * 0.615)
    for text, colour in lines:
        word(c, text, (w - text_width(text, scale)) // 2, y, scale, colour)
        y += int(scale * 9.5)
    sub, s2 = "OVERHAUL", max(1, scale // 2)
    word(c, sub, (w - text_width(sub, s2)) // 2, y + s2 * 3, s2, IRIS_IN)
    tag, s3 = "A COUNTY THAT DECIDES", max(1, scale // 3)
    word(c, tag, (w - text_width(tag, s3)) // 2,
         y + s2 * 3 + int(s2 * 11), s3, DIM)
    return c.png()


def main():
    where = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else None
    art = {"icon.png": icon(), "poster.png": poster()}
    if where is not None:
        where.mkdir(parents=True, exist_ok=True)
        for name, data in art.items():
            (where / name).write_bytes(data)
        return 0
    for folder in (MOD, VERSIONED):
        for name, data in art.items():
            (folder / name).write_bytes(data)
            print(f"  wrote {folder.name}/{name}  ({len(data)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
