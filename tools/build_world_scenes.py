#!/usr/bin/env python3
"""MIT. Authored pixel paintings for source-confirmed mine and works scenes.

Geometry, palettes and texturing below are artistic choices. They express the
original mine.AO / scene2.AO subjects with cold rock, frost, warm lamps, iron and
timber, following the owner's Noita direction. No source assets are sampled.
"""
from pathlib import Path
import random
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "game/assets/world-events"
# source: authored paint canvas fits ECS scene band320x110, drawn at2x detail.
WIDTH, HEIGHT = 640, 220


def base(seed):
    rng = random.Random(seed)
    image = Image.new("RGB", (WIDTH, HEIGHT))
    pixels = image.load()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            grain = rng.randrange(-5, 6)
            pixels[x, y] = (max(0, 16 + y // 12 + grain),
                            max(0, 31 + y // 6 + grain),
                            max(0, 43 + y // 5 + grain))
    return image, ImageDraw.Draw(image), rng


def snow(draw, rng):
    draw.polygon([(0,120),(70,102),(150,114),(220,94),(330,111),
                  (400,92),(505,109),(640,84),(640,220),(0,220)], fill="#75939d")
    for _ in range(3600):
        x, y = rng.randrange(WIDTH), rng.randrange(106, HEIGHT)
        draw.rectangle((x,y,x+rng.randrange(1,5),y+1), fill=rng.choice(
            ["#c2d8d4","#9cb9be","#668790","#87a5ab"]))


def lamp(draw, at):
    x, y = at
    for radius, color in [(21,"#685843"),(14,"#977a50"),(8,"#d4a85d"),(3,"#fff1b7")]:
        draw.ellipse((x-radius,y-radius,x+radius,y+radius), fill=color)
    draw.rectangle((x-4,y-5,x+4,y+6), outline="#252b2b", width=2)
    draw.line((x,y+7,x,y+24), fill="#252b2b", width=2)


def mine():
    image, draw, rng = base(22)
    snow(draw, rng)
    draw.polygon([(0,31),(85,9),(154,40),(210,23),(305,75),(346,163),
                  (260,188),(170,145),(61,171),(0,129)], fill="#263e48")
    for _ in range(1500):
        x, y = rng.randrange(0,340), rng.randrange(25,145)
        draw.line((x,y,x+rng.randrange(3,13),y-2), fill=rng.choice(
            ["#49616a","#344d59","#1c3039","#657b83"]))
    draw.polygon([(99,143),(112,83),(140,59),(196,60),(226,82),(239,147)], fill="#08141c")
    for x in [100,118,220,238]:
        draw.rectangle((x,78,x+7,148), fill="#6b5142")
        draw.line((x+2,82,x+2,143), fill="#a38055", width=2)
    draw.line((111,78,138,56,200,56,231,79), fill="#9a7856", width=10)
    draw.line((110,72,139,51,203,51,234,74), fill="#d0d2b7", width=3)
    for x in range(0, WIDTH, 23):
        y = 151 + x // 10
        draw.line((x,y,x+25,y+12), fill="#433d32", width=6)
        draw.line((x,y-2,x+25,y+10), fill="#9a8061", width=2)
    draw.line((169,128,640,180), fill="#253b42", width=4)
    draw.line((176,137,640,209), fill="#b2b7aa", width=3)
    draw.line((163,138,640,191), fill="#657f87", width=2)
    draw.line((179,146,640,218), fill="#263841", width=3)
    draw.rectangle((397,70,525,139), fill="#3f494b")
    for x in range(400,525,12):
        draw.line((x,73,x,135), fill="#697270", width=2)
    draw.polygon([(390,70),(460,39),(532,69)], fill="#233942")
    draw.line((390,67,460,37,532,66), fill="#ccdbcd", width=4)
    draw.rectangle((429,99,458,139), fill="#172b34")
    draw.rectangle((480,90,504,111), fill="#d5ab5f")
    draw.line((492,89,492,111), fill="#554b3c", width=3)
    lamp(draw, (120,106))
    lamp(draw, (343,127))
    for _ in range(230):
        x, y = rng.randrange(WIDTH), rng.randrange(HEIGHT)
        draw.point((x,y), fill="#c8d9ce")
    return image


def works():
    image, draw, rng = base(24)
    snow(draw, rng)
    draw.polygon([(213,83),(358,84),(417,220),(166,220)], fill="#122b38")
    for y in range(86,220,5):
        draw.line((220-y//5,y,350+y//5,y), fill="#183745", width=2)
    for x in [206,228,251,274,297,320,343,366]:
        draw.line((x,133,x-18,211), fill="#45433c", width=5)
        draw.line((x+1,134,x-16,207), fill="#9d8360", width=2)
    draw.polygon([(167,131),(181,112),(390,112),(407,131)], fill="#3a4344")
    for x in range(173,402,10):
        draw.line((x,129,x+4,113), fill="#a99e82", width=3)
    draw.line((0,140,640,140), fill="#34464a", width=4)
    draw.line((0,150,640,150), fill="#b0b8ab", width=3)
    draw.line((0,165,640,165), fill="#33464d", width=4)
    draw.line((0,169,640,169), fill="#b0b8ab", width=2)
    draw.line((472,129,489,48,493,46,514,129), fill="#273943", width=10)
    draw.line((490,46,309,70), fill="#4c5e61", width=8)
    draw.line((490,43,309,67), fill="#d7c596", width=2)
    draw.line((311,70,311,107), fill="#26343a", width=2)
    draw.rectangle((309,105,314,114), fill="#a48357")
    draw.rectangle((466,132,525,149), fill="#5a4d3e")
    for x in [105,143,404,445]:
        draw.rectangle((x,133,x+6,153), fill="#3c3931")
        draw.rectangle((x-2,126,x+7,134), fill="#b09770")
        draw.rectangle((x-4,137,x+10,145), fill="#6c5741")
        draw.line((x-4,139,x-12,146), fill="#c2aa80", width=3)
        draw.line((x+9,139,x+17,143), fill="#c2aa80", width=3)
    lamp(draw, (90,124))
    lamp(draw, (417,126))
    for x in range(27,130,12):
        draw.line((x,181,x+67,194), fill="#68513a", width=5)
        draw.line((x,178,x+67,191), fill="#bb9a6a", width=2)
    return image


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    mine().save(OUTPUT / "mine.png")
    works().save(OUTPUT / "track-works.png")
    print("Authored mine and works paintings: 640x220 each")


if __name__ == "__main__":
    main()
