import sys,os; sys.path.insert(0,os.path.dirname(__file__)); from alisimg import *
U='/Users/cdeust/Developments/Transartica/reference-private/unpacked/'
SC={}
def S(n):
    if n not in SC: SC[n]=Script(U+n+'.alis')
    return SC[n]
def expand(s,idx,x,dep,z,flip=False,out=None):
    """returns list of (depth, t,w,h,rows,left,top,flip)"""
    if out is None: out=[]
    k=s.kind(idx)
    if k==0xff:
        for (e,dx,dd,dz) in s.composite(idx):
            f=flip
            if e<0: e&=0x7fff; f=not f
            expand(s,e,x+(-dx if flip else dx),dep+dd,z+dz,f,out)
    elif k<0x80:
        t,w,h,rows=s.pixels(idx)
        out.append((dep,t,w,h,rows,x-((w-1)>>1),(199-z)-((h-1)>>1),flip))
    return out
def paint(cv,items,pal,y0=0,y1=200):
    for (dep,t,w,h,rows,L,T,f) in sorted(items,key=lambda a:-a[0]):
        for y in range(h):
            Y=T+y
            if not(y0<=Y<y1): continue
            for x in range(w):
                c=rows[y][w-1-x if f else x]
                if t==0 and c==0: continue
                X=L+x
                if 0<=X<320: cv[Y][X]=pal[c]
def blank(): return [[(0,0,0)]*320 for _ in range(200)]
def save(cv,path,scale=2):
    rows=[]
    for r in cv:
        rr=[p for p in r for _ in range(scale)]
        rows += [rr]*scale
    png(path,320*scale,200*scale,rows)
def panel_from_capture(cv):
    # bottom common panel (lines 149-199) cropped from original 2x capture
    import zlib,struct
    return cv
def read_png_rgb(path):
    import zlib,struct
    d=open(path,'rb').read(); p=8; idat=b''
    while p<len(d):
        n=struct.unpack('>I',d[p:p+4])[0]; t=d[p+4:p+8]; b=d[p+8:p+8+n]; p+=12+n
        if t==b'IHDR': w,h=struct.unpack('>II',b[:8])
        elif t==b'IDAT': idat+=b
    raw=zlib.decompress(idat); bpp=3; stride=w*3; out=[]; prev=bytearray(stride); i=0
    for y in range(h):
        f=raw[i]; i+=1; line=bytearray(raw[i:i+stride]); i+=stride
        for x in range(stride):
            a=line[x-bpp] if x>=bpp else 0; b=prev[x]; c=prev[x-bpp] if x>=bpp else 0
            if f==1: line[x]=(line[x]+a)&255
            elif f==2: line[x]=(line[x]+b)&255
            elif f==3: line[x]=(line[x]+((a+b)>>1))&255
            elif f==4:
                pa=abs(b-c);pb=abs(a-c);pc=abs(a+b-2*c)
                pr=a if pa<=pb and pa<=pc else (b if pb<=pc else c)
                line[x]=(line[x]+pr)&255
        out.append(line); prev=line
    return w,h,out
def paste_panel(cv):
    w,h,rows=read_png_rgb('/Users/cdeust/Developments/Transartica/reference-private/art-direction/original-command-room.png')
    for y in range(149,200):
        r=rows[y*2]
        for x in range(320): cv[y][x]=(r[x*6],r[x*6+1],r[x*6+2])
