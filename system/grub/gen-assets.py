#!/usr/bin/env python3
"""Generate the PNG assets for the Tokyo Night GRUB theme.

Pure stdlib on purpose: a freshly-installed box has python3 but not
ImageMagick or Pillow, and this has to run from bootstrap.

    ./gen-assets.py [outdir]        (default: ./theme)
"""
import os
import struct
import sys
import zlib

W, H = 1920, 1080

# ------------------------------------------------------------- tokyo night
BG        = (0x1a, 0x1b, 0x26)   # base
BG_DARK   = (0x16, 0x16, 0x1e)   # vignette floor
BLUE      = (0x7a, 0xa2, 0xf7)
PURPLE    = (0xbb, 0x9a, 0xf7)
CYAN      = (0x7d, 0xcf, 0xff)
DARK3     = (0x54, 0x5c, 0x7e)


def write_png(path, w, h, rgba):
    """rgba is a bytearray of w*h*4 bytes, top row first."""
    stride = w * 4
    raw = bytearray()
    for y in range(h):
        raw.append(0)                                    # filter: none
        raw += rgba[y * stride:(y + 1) * stride]

    def chunk(tag, data):
        body = tag + data
        return (struct.pack('>I', len(data)) + body
                + struct.pack('>I', zlib.crc32(body) & 0xffffffff))

    out = b'\x89PNG\r\n\x1a\n'
    out += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    out += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    out += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(out)


def clamp(v):
    return 0 if v < 0 else (255 if v > 255 else int(v))


# ----------------------------------------------------------------- background
def background(path):
    """Base gradient + two soft colour glows + a vignette."""
    px = bytearray(W * H * 4)
    cx, cy = W * 0.5, H * 0.30          # blue glow, above the menu
    px2, py2 = W * 0.82, H * 0.88       # purple glow, bottom right
    r1 = W * 0.62
    r2 = W * 0.45
    # Vignette is measured from the centre in normalised coords so it stays
    # circular regardless of the 16:9 frame.
    vcx, vcy = W * 0.5, H * 0.5
    vmax = (vcx ** 2 + vcy ** 2) ** 0.5

    i = 0
    for y in range(H):
        # Vertical base ramp: slightly lighter at the top.
        t = y / (H - 1)
        br = BG[0] + (BG_DARK[0] - BG[0]) * t
        bg = BG[1] + (BG_DARK[1] - BG[1]) * t
        bb = BG[2] + (BG_DARK[2] - BG[2]) * t
        dy1 = (y - cy) ** 2
        dy2 = (y - py2) ** 2
        dvy = (y - vcy) ** 2
        for x in range(W):
            r, g, b = br, bg, bb

            d = ((x - cx) ** 2 + dy1) ** 0.5 / r1
            if d < 1.0:
                a = (1.0 - d) ** 2 * 0.20
                r += (BLUE[0] - r) * a
                g += (BLUE[1] - g) * a
                b += (BLUE[2] - b) * a

            d = ((x - px2) ** 2 + dy2) ** 0.5 / r2
            if d < 1.0:
                a = (1.0 - d) ** 2 * 0.13
                r += (PURPLE[0] - r) * a
                g += (PURPLE[1] - g) * a
                b += (PURPLE[2] - b) * a

            # Darken the corners so the menu keeps the eye.
            v = (((x - vcx) ** 2 + dvy) ** 0.5 / vmax) ** 2 * 0.45
            r *= 1 - v
            g *= 1 - v
            b *= 1 - v

            px[i] = clamp(r); px[i + 1] = clamp(g)
            px[i + 2] = clamp(b); px[i + 3] = 255
            i += 4
    write_png(path, W, H, px)


# ------------------------------------------------------- rounded-rect helper
SS = 4  # supersampling factor for anti-aliasing


def _coverage(w, h, radius, inset=0.0):
    """Per-pixel coverage (0..1) of a rounded rect, supersampled."""
    cov = [0.0] * (w * h)
    step = 1.0 / SS
    off = step / 2.0
    x0 = y0 = inset
    x1, y1 = w - inset, h - inset
    rad = max(0.0, radius - inset)
    for py in range(h):
        for px in range(w):
            hits = 0
            for sy in range(SS):
                fy = py + off + sy * step
                for sx in range(SS):
                    fx = px + off + sx * step
                    if fx < x0 or fx > x1 or fy < y0 or fy > y1:
                        continue
                    # Nearest corner centre; inside the straight edges dx/dy
                    # collapse to 0 and the test is a plain bounds check.
                    dx = max(x0 + rad - fx, fx - (x1 - rad), 0.0)
                    dy = max(y0 + rad - fy, fy - (y1 - rad), 0.0)
                    if dx * dx + dy * dy <= rad * rad:
                        hits += 1
            cov[py * w + px] = hits / float(SS * SS)
    return cov


def rounded_box(w, h, radius, fill, fill_a, border=None, border_a=0.0,
                border_w=1.0):
    """Filled rounded rect, optionally with an inner border ring."""
    outer = _coverage(w, h, radius)
    inner = _coverage(w, h, radius, inset=border_w) if border else None
    px = bytearray(w * h * 4)
    for n in range(w * h):
        o = outer[n]
        if o <= 0.0:
            continue
        if inner is None:
            cr, cg, cb, ca = fill[0], fill[1], fill[2], fill_a * o
        else:
            i = inner[n]
            ring = max(0.0, o - i)
            fa = fill_a * i
            ba = border_a * ring
            ca = fa + ba * (1 - fa)
            if ca <= 0.0:
                continue
            # Border over fill, straight source-over in premultiplied space.
            cr = (border[0] * ba + fill[0] * fa * (1 - ba)) / ca
            cg = (border[1] * ba + fill[1] * fa * (1 - ba)) / ca
            cb = (border[2] * ba + fill[2] * fa * (1 - ba)) / ca
        j = n * 4
        px[j] = clamp(cr); px[j + 1] = clamp(cg)
        px[j + 2] = clamp(cb); px[j + 3] = clamp(ca * 255)
    return px


def crop(src, sw, x, y, w, h):
    out = bytearray(w * h * 4)
    for row in range(h):
        s = ((y + row) * sw + x) * 4
        out[row * w * 4:(row + 1) * w * 4] = src[s:s + w * 4]
    return out


def nine_slice(outdir, prefix, radius, fill, fill_a, border=None,
               border_a=0.0, border_w=1.0, slice_x=None, slice_y=None):
    """Slice one rendered rounded rect into GRUB's *_nw/_n/_ne/... set.

    GRUB stretches _n/_s horizontally, _w/_e vertically and _c both ways, so
    the edge strips only need to be 1px along the stretched axis.

    slice_x/slice_y default to the corner radius but can be larger. GRUB draws
    the box so its slices sit *outside* the item's content rect, so a slice
    wider than the visible curve becomes transparent padding — that is the
    only way to inset a menu label from the selection border. Widening
    slice_y likewise means item_spacing must be at least 2*slice_y or
    neighbouring boxes will overlap.
    """
    sx = radius if slice_x is None else slice_x
    sy = radius if slice_y is None else slice_y
    if sx < radius or sy < radius:
        raise ValueError('slice must be >= radius, else the curve is clipped')
    w, h = 2 * sx + 2, 2 * sy + 2
    src = rounded_box(w, h, radius, fill, fill_a, border, border_a, border_w)
    parts = {
        'nw': (0, 0, sx, sy),           'n': (sx, 0, 1, sy),
        'ne': (sx + 2, 0, sx, sy),      'w': (0, sy, sx, 1),
        'c':  (sx, sy, 1, 1),           'e': (sx + 2, sy, sx, 1),
        'sw': (0, sy + 2, sx, sy),      's': (sx, sy + 2, 1, sy),
        'se': (sx + 2, sy + 2, sx, sy),
    }
    for name, (x, y, pw, ph) in parts.items():
        write_png(os.path.join(outdir, '%s_%s.png' % (prefix, name)),
                  pw, ph, crop(src, w, x, y, pw, ph))


def solid(path, w, h, color, alpha):
    px = bytearray(w * h * 4)
    for n in range(w * h):
        j = n * 4
        px[j] = color[0]; px[j + 1] = color[1]
        px[j + 2] = color[2]; px[j + 3] = clamp(alpha * 255)
    write_png(path, w, h, px)


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else \
        os.path.join(os.path.dirname(os.path.abspath(__file__)), 'theme')
    os.makedirs(outdir, exist_ok=True)

    background(os.path.join(outdir, 'background.png'))

    # Selected menu entry: translucent blue slab with a brighter edge.
    # slice_x 20 gives the label a 20px inset from the border; slice_y 10
    # is matched by item_spacing in theme.txt.
    nine_slice(outdir, 'select', 8, BLUE, 0.17, BLUE, 0.55, 1.5,
               slice_x=20, slice_y=10)

    # Countdown bar: dark trough, blue fill.
    # Radius 4 keeps the slices small: GRUB cannot draw a nine-slice box
    # shorter than its top + bottom slices, so this caps the trough at 8px.
    nine_slice(outdir, 'progress', 4, DARK3, 0.28)
    nine_slice(outdir, 'progress_hl', 4, BLUE, 0.90)

    # Thin accent rule under the title.
    solid(os.path.join(outdir, 'rule.png'), 1, 1, CYAN, 0.45)

    print('wrote assets to %s' % outdir)


if __name__ == '__main__':
    main()
