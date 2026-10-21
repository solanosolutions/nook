"""Junta os PNGs capturados em um GIF leve para o README. Uso: python frames-to-gif.py <pasta> <saida.gif>"""
import sys
from pathlib import Path
from PIL import Image

src, out = Path(sys.argv[1]), Path(sys.argv[2])
frames = [Image.open(p).convert("RGB") for p in sorted(src.glob("f*.png"))]
# Paleta única (derivada de alguns quadros) evita "piscar" de cor entre quadros
sample = Image.new("RGB", (frames[0].width, frames[0].height * 4))
for i, f in enumerate(frames[:: max(1, len(frames) // 4)][:4]):
    sample.paste(f, (0, i * frames[0].height))
palette = sample.quantize(colors=200, method=Image.Quantize.MEDIANCUT)
gif = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
gif[0].save(out, save_all=True, append_images=gif[1:], duration=70, loop=0, optimize=True, disposal=1)
print(f"OK: {out} ({len(gif)} quadros, {out.stat().st_size / 1024:.0f} KB)")
