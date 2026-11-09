"""Tiny flat-vector scene: polygons and round-capped strokes, rendered to SVG and to Pillow
(4x supersampled, box-filtered down) from the same baked points, so SVG and PNG match."""
import math

from PIL import Image, ImageDraw

from pal import P, rgb


def col(c):
    return P.get(c, c)


# ---------- point helpers (all return lists of (x, y)) ----------

def ellipse(cx, cy, rx, ry, n=96, rot=0.0):
    return arc(cx, cy, rx, ry, 0, 360, n, rot)[:-1]


def arc(cx, cy, rx, ry, a0, a1, n=48, rot=0.0):
    pts = []
    cr, sr = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        x, y = rx * math.cos(a), ry * math.sin(a)
        pts.append((cx + x * cr - y * sr, cy + x * sr + y * cr))
    return pts


def circle(cx, cy, r, n=72):
    return ellipse(cx, cy, r, r, n)


def rrect(x, y, w, h, r, n=10):
    r = min(r, w / 2, h / 2)
    pts = []
    for cx, cy, a0 in ((x + w - r, y + r, -90), (x + w - r, y + h - r, 0), (x + r, y + h - r, 90), (x + r, y + r, 180)):
        pts += arc(cx, cy, r, r, a0, a0 + 90, n)
    return pts


def star(cx, cy, ro, ri, k=5, rot=-90.0, round_n=0):
    pts = []
    for i in range(2 * k):
        a = math.radians(rot + 180.0 * i / k)
        r = ro if i % 2 == 0 else ri
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def bezier(p0, p1, p2, p3, n=32):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append((u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                    u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]))
    return out


def xform(pts, tx=0.0, ty=0.0, s=1.0, rot=0.0, sx=1.0, sy=1.0, ox=0.0, oy=0.0):
    """Scale (s*sx, s*sy) and rotate (degrees) about (ox, oy), then translate."""
    c, si = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    out = []
    for x, y in pts:
        x, y = (x - ox) * s * sx, (y - oy) * s * sy
        out.append((ox + x * c - y * si + tx, oy + x * si + y * c + ty))
    return out


# ---------- scene ----------

class Scene:
    def __init__(self, w, h, bg=None):
        self.w, self.h, self.bg = w, h, bg
        self.items = []

    def poly(self, pts, fill=None, stroke=None, sw=0.0, alpha=1.0):
        self.items.append(("poly", list(pts), fill, stroke, sw, alpha))

    def line(self, pts, color, width, closed=False, alpha=1.0):
        pts = list(pts)
        if closed:
            pts = pts + pts[:2]
        self.items.append(("line", pts, color, width, alpha))

    def outlined(self, parts, ow, ink="ink", details=()):
        """Sticker style: every part's outline is drawn first, then every fill, so touching parts
        share one merged outline. parts: [(pts, fill)] polygons or [("line", pts, fill, width)]."""
        for p in parts:
            if p[0] == "line":
                _, pts, _, w = p
                self.line(pts, ink, w + 2 * ow)
            else:
                self.poly(p[0], fill=ink, stroke=ink, sw=2 * ow)
        for p in parts:
            if p[0] == "line":
                _, pts, fill, w = p
                self.line(pts, fill, w)
            else:
                self.poly(p[0], fill=p[1])
        for d in details:
            if d[0] == "line":
                self.line(d[1], d[2], d[3])
            else:
                self.poly(d[0], fill=d[1])

    def extend(self, other):
        self.items += other.items

    # ----- SVG -----
    def svg(self, title="Open Jar Games"):
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" '
               f'width="{self.w}" height="{self.h}">', f"<title>{title}</title>"]
        if self.bg:
            out.append(f'<rect width="{self.w}" height="{self.h}" fill="{col(self.bg)}"/>')
        for it in self.items:
            if it[0] == "poly":
                _, pts, fill, stroke, sw, a = it
                d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z"
                attrs = f'fill="{col(fill)}"' if fill else 'fill="none"'
                if stroke and sw:
                    attrs += f' stroke="{col(stroke)}" stroke-width="{sw:.1f}" stroke-linejoin="round"'
                if a < 1:
                    attrs += f' opacity="{a:.2f}"'
                out.append(f'<path d="{d}" {attrs}/>')
            else:
                _, pts, c, w, a = it
                d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts)
                op = f' opacity="{a:.2f}"' if a < 1 else ""
                out.append(f'<path d="{d}" fill="none" stroke="{col(c)}" stroke-width="{w:.1f}" '
                           f'stroke-linecap="round" stroke-linejoin="round"{op}/>')
        out.append("</svg>")
        return "\n".join(out) + "\n"

    # ----- raster -----
    def render(self, scale=1.0, ss=4):
        k = scale * ss
        W, H = round(self.w * scale), round(self.h * scale)
        img = Image.new("RGBA", (W * ss, H * ss), rgb(self.bg) + (255,) if self.bg else (0, 0, 0, 0))
        for it in self.items:
            a = it[-1]
            target = img if a >= 1 else Image.new("RGBA", img.size, (0, 0, 0, 0))
            d = ImageDraw.Draw(target)
            if it[0] == "poly":
                _, pts, fill, stroke, sw, _ = it
                sp = [(x * k, y * k) for x, y in pts]
                if fill:
                    d.polygon(sp, fill=rgb(col(fill)) + (255,))
                if stroke and sw:
                    _stroke(d, sp + sp[:1], rgb(col(stroke)), sw * k)
            else:
                _, pts, c, w, _ = it
                _stroke(d, [(x * k, y * k) for x, y in pts], rgb(col(c)), w * k)
            if a < 1:
                r, g, b, al = target.split()
                al = al.point(lambda v: int(v * a))
                target.putalpha(al)
                img.alpha_composite(target)
        return img.resize((W, H), Image.Resampling.BOX)


def _stroke(d, pts, c, w):
    """Segments plus a disc at every vertex: clean round joins and caps at any width."""
    fill = c + (255,)
    wi = max(1, round(w))
    r = w / 2
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        d.line([(x0, y0), (x1, y1)], fill=fill, width=wi)
    for x, y in pts:
        d.ellipse((x - r, y - r, x + r, y + r), fill=fill)
