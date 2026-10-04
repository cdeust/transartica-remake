#!/usr/bin/env python3
"""MIT. Author pixel materials and scenery; never sample historical pixel data.

96px art cells and palette/layout values are authored presentation choices.
Resource associations are inspected CARTE images65..151 (world-terrain.md).
"""
from pathlib import Path
import hashlib
from PIL import Image, ImageDraw
import random

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/assets/travel/terrain'
OUT.mkdir(parents=True, exist_ok=True)
S=96
P={'snow':'#b1c4c9','light':'#dbe1d6','blue':'#829eaa','shade':'#5d7884','deep':'#314751','rock':'#435661','edge':'#65808b','warm':'#b48a55','amber':'#e3b775','iron':'#253942','water':'#426e82','waterlight':'#6e9cae','pine':'#304c50','pinehi':'#56716c'}

def grain(im,seed,strength=1):
    # Correlated short material strokes, clipped to already-painted surfaces.
    r=random.Random(seed);d=ImageDraw.Draw(im)
    for _ in range(180):
        x=r.randrange(S);y=r.randrange(S)
        if im.getpixel((x,y))[3]:
            c=im.getpixel((x,y));v=r.choice((-6,-3,3,6))*strength
            d.line((x,y,min(S-1,x+r.randrange(1,4)),y),fill=tuple(max(0,min(255,n+v)) for n in c[:3])+(c[3],))


def mountain(i):
    im=Image.new('RGBA',(S,S));d=ImageDraw.Draw(im)
    peaks=[(21+(i*11)%24,24+(i%4)*9),(63+(i*7)%14,15+(i%3)*12)]
    d.polygon([(0,80),(12,62),*peaks,(95,78),(95,95),(0,95)],fill=P['shade'])
    for x,y in peaks:
        d.polygon([(max(0,x-28),88),(x,y),(min(95,x+37),88)],fill=P['rock'])
        d.polygon([(max(0,x-28),88),(x,y),(x-3,y+38),(x-16,72)],fill=P['edge'])
        d.polygon([(x,y),(x+4,y+12),(x+15,y+24),(x+7,y+21),(x+2,y+28),(x-5,y+20),(x-13,y+32),(x-10,y+17)],fill=P['light'])
        d.line([(x-10,y+17),(x-13,y+32),(x-18,y+49),(x-27,77)],fill=P['snow'],width=3)
        for k in range(4):
            d.line((x+5+k*4,y+27+k*7,min(95,x+18+k*4),y+39+k*7),fill=P['deep'],width=2)
    d.polygon([(0,88),(15,80),(29,89),(50,81),(63,89),(80,84),(95,90),(79,93),(53,91),(25,94)],fill=P['snow'])
    for yy in range(86,96):
        for xx in range(96):
            c=im.getpixel((xx,yy));im.putpixel((xx,yy),c[:3]+(int(c[3]*(95-yy)/9),))
    grain(im,i);return im


# source: CARTE palette5..8 bounds/openings measured in private map-resources.json.
# Modern polygons below preserve only those semantic limits, never source pixels.
SHORE_OPENINGS = {
    106: {"E": (2,11)},
    107: {"E": (7,16), "S": (10,16), "W": (2,12)},
    108: {"E": (7,16), "S": (0,16), "W": (7,16)},
    109: {"S": (0,11), "W": (6,16)},
    110: {"N": (5,16), "E": (0,13)},
    111: {"N": (0,16), "E": (0,14), "W": (0,13)},
    112: {"N": (0,11), "W": (0,14)},
    113: {"E": (1,16), "S": (13,16)},
    114: {"E": (2,11), "S": (0,6), "W": (1,16)},
    115: {"W": (1,11)},
    134: {},
    135: {"N": (3,15), "E": (3,6), "S": (3,15), "W": (3,11)},
    136: {"N": (1,13), "E": (2,10), "S": (1,13), "W": (2,10)},
    137: {"N": (5,15)},
    138: {"E": (1,16), "S": (3,16)},
    139: {"N": (1,14), "E": (2,11), "S": (1,14), "W": (1,15)},
    140: {"N": (3,15), "S": (4,15)},
    149: {"E": (6,7)},
}
SOURCE_CELL = 16  # source: CARTE resource106..149 width and height.
# source: authored contours registered to the measured openings and water bounds
# in map-resources.json. Interior vertex choices are new artwork, not pixel traces.
CORRECTED_SHAPES = {
    106: [(96,12),(60,12),(24,24),(12,42),(24,60),(60,66),(96,66)],
    107: [(0,12),(24,12),(48,24),(70,42),(96,42),(96,96),(60,96),(48,76),(0,72)],
    108: [(0,42),(28,48),(48,42),(70,48),(96,42),(96,96),(0,96)],
    109: [(0,36),(54,36),(90,54),(78,76),(66,96),(0,96)],
    110: [(30,0),(96,0),(96,78),(66,78),(42,60),(30,36)],
    111: [(0,0),(96,0),(96,84),(70,78),(48,84),(24,72),(0,78)],
    112: [(0,0),(66,0),(84,30),(90,54),(60,78),(0,84)],
    113: [(96,6),(60,6),(30,18),(12,36),(30,60),(66,84),(78,96),(96,96)],
    114: [(0,6),(42,6),(72,12),(96,12),(96,66),(66,66),(42,84),(36,96),(0,96)],
    115: [(0,6),(36,6),(60,24),(66,48),(48,66),(30,78),(0,66)],
    135: [(18,0),(90,0),(96,18),(96,36),(78,54),(90,96),(18,96),(12,78),(0,66),(0,18)],
    136: [(6,0),(78,0),(96,12),(96,60),(78,96),(6,96),(0,60),(0,12)],
    137: [(30,0),(90,0),(90,48),(78,66),(54,84),(18,72),(6,42),(18,18)],
    138: [(96,6),(78,6),(54,24),(30,48),(12,72),(18,96),(96,96)],
    139: [(6,0),(84,0),(96,12),(96,66),(84,96),(6,96),(0,90),(0,6)],
    140: [(18,0),(90,0),(90,30),(78,60),(90,96),(24,96),(12,72),(18,42)],
    149: [(96,36),(78,24),(42,18),(12,30),(6,48),(24,72),(48,78),(78,66),(90,48),(96,42)],
}

def register_shore_edges(im, code):
    """Register modern water openings to measured source border intervals."""
    scale = S // SOURCE_CELL
    for side in "NESW":
        opening = SHORE_OPENINGS[code].get(side)
        for position in range(S):
            point = {"N": (position,0), "E": (S-1,position),
                     "S": (position,S-1), "W": (0,position)}[side]
            water = opening and opening[0]*scale <= position < opening[1]*scale
            im.putpixel(point, (*bytes.fromhex(P["water"][1:]),255) if water else (0,0,0,0))
    return im


def lake(i):
    im=Image.new('RGBA',(S,S));d=ImageDraw.Draw(im)
    # Individual shore compositions preserve the original tile's lake association.
    shape = CORRECTED_SHAPES[i]
    d.polygon(shape,fill=P['water'])
    for a,b in zip(shape,shape[1:]+shape[:1]):
        if (a[0]==b[0] and a[0] in (0,96)) or (a[1]==b[1] and a[1] in (0,96)):continue
        d.line((a,b),fill=P['blue'],width=7);d.line((a,b),fill=P['light'],width=2)
    mask=im.copy();r=random.Random(i)
    for _ in range(18):
        x=r.randrange(5,90);y=r.randrange(8,92)
        if mask.getpixel((x,y))[3]:d.line((x,y,min(95,x+r.randrange(8,22)),y),fill=P['waterlight'])
    for pts in [[(8,45),(22,39),(34,43),(49,35)],[(65,8),(62,28),(69,38),(61,50)]]:
        for a,b in zip(pts,pts[1:]):
            if mask.getpixel(a)[3] and mask.getpixel(b)[3]:d.line((a,b),fill=P['blue'])
    if i in SHORE_OPENINGS:
        register_shore_edges(im, i)
    return im


def oasis():
    """Authored vegetation and enclosed pool; source134 has green palms/basin."""
    im = Image.new("RGBA", (S,S)); d = ImageDraw.Draw(im)
    # source: palette14/15 vegetation and blue water bbox(1,6)..(14,13),
    # inspected map-resources134; new leaves/shore shapes are presentation.
    d.ellipse((6,36,84,78), fill=P["water"])
    d.arc((6,36,84,78), 0, 360, fill=P["blue"], width=3)
    for x,y in [(18,27),(38,22),(58,25),(73,32),(21,46),(67,51)]:
        d.line((x,y,x+3,y+18), fill=P["warm"], width=3)
        for dx,dy in [(-10,4),(-7,-5),(0,-8),(8,-4),(11,4)]:
            d.line((x,y,x+dx,y+dy), fill=P["pine"], width=4)
            d.line((x,y,x+dx,y+dy), fill=P["pinehi"], width=2)
    return register_shore_edges(im, 134)


def forest(i):
    im=Image.new('RGBA',(S,S));d=ImageDraw.Draw(im);r=random.Random(i)
    # Dense connected clumps, never global random decorative scatter.
    for row in range(3):
        for col in range(4):
            x=col*24+8+r.randrange(-3,4);y=row*24+24+r.randrange(-4,5);h=24+r.randrange(8)
            d.ellipse((x-10,y+8,x+19,y+18),fill=(36,59,64,100))
            d.rectangle((x,y-3,x+2,y+13),fill=P['deep'])
            for k in range(3):
                yy=y-h+k*10;w=5+k*5
                d.polygon([(x,yy),(x-w,yy+15),(x+w+2,yy+15)],fill=P['pine'])
                d.line((x,yy,x-w,yy+15),fill=P['pinehi'],width=2)
                d.line((x-1,yy+2,x-w+2,yy+13),fill=P['snow'],width=3)
                d.line((x-w+3,yy+14,x+1,yy+14),fill=P['light'])
    return im


def building(d,rect,style=0):
    x,y,w,h=rect
    d.rectangle((x+4,y+h-3,x+w+9,y+h+9),fill=(35,49,54,100))
    d.rectangle((x,y,x+w,y+h),fill=P['iron']);d.rectangle((x+2,y+2,x+w-2,y+h-1),fill=P['shade'])
    d.rectangle((x+w-6,y+2,x+w-1,y+h),fill=P['rock'])
    d.polygon([(x-3,y+2),(x+w//2,y-9),(x+w+3,y+2),(x+w,y+7),(x-2,y+7)],fill=P['snow'])
    d.line((x-2,y+1,x+w//2,y-8),fill=P['light'],width=3)
    for xx in range(x+4,x+w-4,7):
        d.rectangle((xx,y+12,xx+3,y+16),fill=P['amber'] if style else P['blue'])
    d.rectangle((x+w//2-3,y+h-10,x+w//2+3,y+h),fill=P['deep'])


def city(i):
    im=Image.new('RGBA',(S,S));d=ImageDraw.Draw(im)
    d.ellipse((3,36,94,94),fill=(39,60,68,85))
    if i in (78,79):
        d.polygon([(9,88),(16,45),(42,24),(79,39),(92,90)],fill=P['rock'])
        d.polygon([(14,45),(41,24),(79,39),(71,47),(48,36),(22,56)],fill=P['snow'])
        d.rectangle((31,52,68,91),fill=P['deep']);d.line((29,91,29,51,70,51,70,91),fill=P['warm'],width=4)
        d.line((34,90,62,59),fill=P['warm'],width=2) if i==79 else None
        d.rectangle((73,73,83,90),fill=P['iron']);d.rectangle((74,74,82,77),fill=P['amber'])
        return im
    layout={71:[(6,36,42,37),(51,51,32,26)],72:[(8,49,27,30),(36,33,48,41)],73:[(8,32,24,26),(35,46,24,32),(62,27,23,34)],74:[(9,37,55,37),(66,57,23,24)],75:[(8,30,72,47)],76:[(7,53,45,27),(56,40,29,36)]}.get(i,[(8,39,35,29),(43,50,39,31),(44,24,25,21)])
    for index,(x,y,w,h) in enumerate(layout):building(d,(x,y,w,h),index%2)
    if i==72:
        d.rectangle((17,18,25,44),fill=P['iron']);d.rectangle((15,17,27,23),fill=P['snow'])
    if i==74:
        for x,y in [(16,80),(26,84),(72,42),(80,46)]:
            d.rectangle((x,y,x+7,y+7),fill=P['warm']);d.line((x,y,x+7,y+7),fill=P['deep'])
    if i==75:
        d.rectangle((55,11,63,28),fill=P['warm']);d.rectangle((53,9,65,14),fill=P['snow'])
        for x in (18,37,56):d.rectangle((x,57,x+10,77),fill=P['deep'])
    if i==76:
        d.rectangle((17,18,19,50),fill=P['iron']);d.rectangle((36,18,38,50),fill=P['iron'])
        d.ellipse((11,6,43,26),fill=P['shade']);d.rectangle((11,12,43,26),fill=P['shade']);d.line((11,12,43,12),fill=P['light'],width=3)
    for y in range(50,79,5):
        for x in range(10+(y%2)*3,84,8):
            if im.getpixel((x,y))[3]:d.line((x,y,x+3,y),fill=P['edge'])
    d.rectangle((15,17,22,39),fill=P['iron']);d.rectangle((15,17,19,39),fill=P['warm']);d.rectangle((13,14,24,18),fill=P['snow'])
    d.rectangle((5,83,87,85),fill=P['rock']);d.line((5,82,87,82),fill=P['light'])
    if i in (65,77,80,84,85,133,147,148):
        d.rectangle((75,17,86,67),fill=P['rock']);d.rectangle((74,17,85,22),fill=P['snow'])
        d.line((75,18,75,66),fill=P['edge'],width=2)
    grain(im,i);return im


# source: image_gen output 4 October2026, unedited1254px square; provenance
# and full prompt: assets/travel/terrain/snow-master-provenance.md.
SNOW_MASTER_SHA256 = "e4889d41b250181b99ae20f8e678133edac056dcb5092f6e514dfc6677c91b41"


def verify_snow_master():
    """Retain committed artwork byte-identically; never regenerate its pixels."""
    path = OUT / "snow-master.png"
    if hashlib.sha256(path.read_bytes()).hexdigest() != SNOW_MASTER_SHA256:
        raise ValueError("Committed snow master differs from its documented image_gen output")
    return path


def build(codes=None):
    if codes is None:
        verify_snow_master()
    selected = codes if codes is not None else [65,*range(71,86),*range(86,116),*range(116,141),142,143,144,145,146,147,148,149]
    for i in selected:
        if 86<=i<=105 or i in (142,143,144,145,146):im=mountain(i)
        elif i == 134:im=oasis()
        elif 106<=i<=115 or i in (135,136,137,138,139,140,149):im=lake(i)
        elif 116<=i<=132:im=forest(i)
        else:im=city(i)
        im.save(OUT/f'{i}.png')
    print(f'Authored {len(list(OUT.glob("*.png")))} terrain/material textures')


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codes", nargs="+", type=int, help="Rebuild only these authored resources; retain snow and other artwork")
    build(parser.parse_args().codes)
