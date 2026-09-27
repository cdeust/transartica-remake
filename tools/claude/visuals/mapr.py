import sys; sys.path.insert(0,'.'); from compose import *
m=open('/Users/cdeust/Developments/Transartica/reference-private/CARTE.FIC','rb').read()
c=S('carte'); pal=c.palette(0)
tiles={i:c.pixels(i) for i in range(1,152)}
def render(x0,y0,cols,rows,bgc=pal[9]):
    W=cols*16;H=rows*16
    cv=[[bgc]*W for _ in range(H)]
    for ty in range(rows):
        for tx in range(cols):
            X=x0+tx;Y=y0+ty
            if not(0<=X<160 and 0<=Y<73): continue
            code=m[X*73+Y]
            if code==0 or code>151: continue
            t,w,h,r=tiles[code]
            px=tx*16; py=ty*16+((15-h)//2)
            for y in range(h):
                for x in range(w):
                    cc=r[y][x]
                    if t==0 and cc==0: continue
                    if 0<=py+y<H and 0<=px+x<W: cv[py+y][px+x]=pal[cc]
    return cv,W,H
cv,W,H=render(0,0,160,73)
png('decoded-detailed-map-full.png',W,H,cv)
# local 320x150 window centred on start (12,62)
cv,W,H=render(12-10,62-5,20,10)
cv=cv[:149]
big=[]
for r in cv:
    rr=[p for p in r for _ in range(2)]; big+=[rr,rr]
png('decoded-detailed-map-window-start-x2.png',640,len(big),big)
