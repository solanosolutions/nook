"""Monta o vídeo vertical (1080x1920, 30 fps) a partir das cenas gravadas por capture-reel.ps1.
Uso: python make-reel.py <pasta-das-cenas> <saida.mp4>"""
import math, subprocess, sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

W, H, FPS = 1080, 1920, 30
SRC, OUT = Path(sys.argv[1]), Path(sys.argv[2])
ROOT = Path(__file__).resolve().parents[1]
FONT_BOLD, FONT = r"C:\Windows\Fonts\seguisb.ttf", r"C:\Windows\Fonts\segoeui.ttf"
GREEN = (30, 215, 96)

def font(size, bold=True): return ImageFont.truetype(FONT_BOLD if bold else FONT, size)

# ---------- fundo (mesmo clima do GIF: gradiente escuro com manchas de cor) ----------
def background():
    bg = Image.new("RGB", (W, H))
    px = bg.load()
    for y in range(H):
        t = y / H
        c = tuple(int(a + (b - a) * t) for a, b in zip((24, 18, 43), (10, 38, 52)))
        for x in range(W): px[x, y] = c
    glow = Image.new("RGB", (W, H)); d = ImageDraw.Draw(glow)
    for cx, cy, r, col in [(0.25, 0.3, 420, (120, 60, 200)), (0.8, 0.45, 380, (30, 200, 120)), (0.4, 0.75, 460, (40, 120, 220))]:
        d.ellipse((W * cx - r, H * cy - r, W * cx + r, H * cy + r), fill=tuple(int(v * 0.55) for v in col))
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    return ImageChops.screen(bg, glow)

BG = background()

# ---------- cenas gravadas ----------
def scene(label):
    files = sorted(SRC.glob(f"{label}_*.bmp"))
    return [(int(f.stem.split("_")[1]) / 1000, f) for f in files]

SCENES = {k: scene(k) for k in ("idle", "hover", "bars")}
first = Image.open(SCENES["idle"][0][1])
PW = 960; PH = round(first.height * PW / first.width)
radius = round(12 * PW / first.width)
MASK = Image.new("L", (PW, PH), 0); ImageDraw.Draw(MASK).rounded_rectangle((0, 0, PW - 1, PH - 1), radius, fill=255)
cache = {}

def player_frame(label, t):
    frames = SCENES[label]
    _, f = min(frames, key=lambda p: abs(p[0] - t))
    if f not in cache:
        cache.clear()
        cache[f] = Image.open(f).convert("RGB").resize((PW, PH), Image.LANCZOS)
    return cache[f]

# ---------- texto ----------
def centered(draw, y, text, fnt, fill=(255, 255, 255), alpha=1.0):
    fill = tuple(int(c) for c in fill) + (int(255 * alpha),)
    for i, line in enumerate(text.split("\n")):
        w = draw.textlength(line, font=fnt)
        draw.text(((W - w) / 2, y + i * fnt.size * 1.25), line, font=fnt, fill=fill)

def ease(x): return 0.5 - 0.5 * math.cos(math.pi * max(0, min(1, x)))

ICON = Image.open(ROOT / "Assets" / "nook.png").convert("RGBA").resize((300, 300), Image.LANCZOS)

# (duração, cena do player ou None, legenda)
TIMELINE = [
    (3.0, None, "intro"),
    (3.3, "idle", "Ele fica quietinho\nno canto da tela"),
    (3.3, "hover", "Passou o mouse?\nNítido."),
    (3.3, "bars", "E reage à música\nde verdade"),
    (3.0, None, "outro"),
]

def render(seg, t, dur):
    kind, caption = seg[1], seg[2]
    img = BG.copy().convert("RGBA")
    layer = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(layer)
    fade = ease(t / 0.35) * ease((dur - t) / 0.35)

    if caption == "intro":
        centered(d, 690, "POV:", font(84), GREEN, fade)
        centered(d, 820, "você só queria\npausar a música", font(92), alpha=fade)
        centered(d, 1100, "...sem abrir o Spotify inteiro", font(52, False), (200, 200, 215), ease((t - 0.8) / 0.4) * fade)
    elif caption == "outro":
        a = ease(t / 0.4)
        icon = ICON.copy(); icon.putalpha(ICON.getchannel("A").point(lambda v: int(v * a)))
        layer.alpha_composite(icon, ((W - 300) // 2, 560))
        centered(d, 900, "Nook", font(120), alpha=a)
        centered(d, 1065, "mini player para o Spotify", font(54, False), (210, 210, 225), a)
        centered(d, 1160, "grátis  •  open source", font(58), GREEN, ease((t - 0.5) / 0.4))
        centered(d, 1320, "link na bio", font(50, False), (230, 230, 240), ease((t - 1.0) / 0.4))
    else:
        frame = player_frame(kind, t)
        y = (H - PH) // 2 + 80
        img.paste(frame, ((W - PW) // 2, y), MASK)
        centered(d, 620, caption, font(80), alpha=fade)

    img.alpha_composite(layer)
    return img.convert("RGB")

ff = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                       "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "18",
                       "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUT)], stdin=subprocess.PIPE)
total = 0
for seg in TIMELINE:
    dur = seg[0]
    for i in range(int(dur * FPS)):
        ff.stdin.write(render(seg, i / FPS, dur).tobytes()); total += 1
ff.stdin.close(); ff.wait()
print(f"OK: {OUT} ({total / FPS:.1f}s, {OUT.stat().st_size / 1024 / 1024:.1f} MB)")
