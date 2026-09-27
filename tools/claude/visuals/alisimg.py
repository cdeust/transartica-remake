import struct,zlib,sys,os
def r16(d,o): return struct.unpack('>H',d[o:o+2])[0]
def s16(d,o): return struct.unpack('>h',d[o:o+2])[0]
def r32(d,o): return struct.unpack('>i',d[o:o+4])[0]
def png(path,w,h,rgb):  # rgb: list of rows of (r,g,b)
    raw=b''.join(b'\x00'+bytes(c for px in row for c in px) for row in rgb)
    def ch(t,b): return struct.pack('>I',len(b))+t+b+struct.pack('>I',zlib.crc32(t+b)&0xffffffff)
    open(path,'wb').write(b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+ch(b'IDAT',zlib.compress(raw,9))+ch(b'IEND',b''))
class Script:
    def __init__(s,path):
        s.d=open(path,'rb').read(); d=s.d
        s.l=r32(d,0xe); s.n=r16(d,s.l+4)
    def res(s,i):
        d=s.d;a=r32(d,s.l)+s.l+i*4; return r32(d,a)+a
    def kind(s,i): return s.d[s.res(i)]
    def palette(s,i):
        d=s.d;at=s.res(i); assert d[at]==0xfe
        p=[]
        for k in range(16):
            b0=d[at+2+2*k];b1=d[at+3+2*k]
            p.append(((b0&15)*17,(b1>>4)*17,(b1&15)*17))
        return p
    def pixels(s,i):
        d=s.d;at=s.res(i);t=d[at];w=r16(d,at+2)+1;h=r16(d,at+4)+1
        if t==1: return t,w,h,[[d[at+1]]*w for _ in range(h)]
        bw=(w+1)//2; base=at+6; rows=[]
        for y in range(h):
            row=[]
            for x in range(w):
                b=d[base+y*bw+x//2]; row.append(b>>4 if x%2==0 else b&15)
            rows.append(row)
        return t,w,h,rows
    def composite(s,i):
        d=s.d;at=s.res(i);n=d[at+1];out=[]
        for k in range(n):
            o=at+2+8*k; out.append((s16(d,o),s16(d,o+2),s16(d,o+4),s16(d,o+6)))
        return out
def render(canvas_w,canvas_h,layers,pal,bg=(0,0,0)):
    cv=[[bg]*canvas_w for _ in range(canvas_h)]
    for (t,w,h,rows,cx,cy,flip) in layers:
        x0=cx-((w-1)>>1); y0=cy-((h-1)>>1)
        for y in range(h):
            for x in range(w):
                c=rows[y][w-1-x if flip else x]
                if t==0 and c==0: continue
                X=x0+x;Y=y0+y
                if 0<=X<canvas_w and 0<=Y<canvas_h: cv[Y][X]=pal[c]
    return cv
