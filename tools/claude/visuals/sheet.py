import sys; sys.path.insert(0,'.'); from compose import *
def sheet(script,ids,palidx,out,cols=8,cell=None,scale=2,bg=(40,40,40)):
    s=S(script); pal=s.palette(palidx)
    ims=[s.pixels(i) for i in ids]
    cw=max(w for t,w,h,r in ims)+4; ch=max(h for t,w,h,r in ims)+4
    if cell: cw,ch=cell
    rows_n=(len(ids)+cols-1)//cols
    W=cw*cols; H=ch*rows_n
    cv=[[bg]*W for _ in range(H)]
    for k,(t,w,h,r) in enumerate(ims):
        ox=(k%cols)*cw+2; oy=(k//cols)*ch+2
        for y in range(min(h,ch-2)):
            for x in range(min(w,cw-2)):
                c=r[y][x]
                if t==0 and c==0: continue
                cv[oy+y][ox+x]=pal[c]
    big=[]
    for r in cv:
        rr=[p for p in r for _ in range(scale)]; big+=[rr]*scale
    png(out,W*scale,H*scale,big)
    print(out,W*scale,H*scale)
if __name__=='__main__':
    sheet('glieu',list(range(31,47)),20,'raw/glieu_goods_icons.png',cols=8)
    sheet('glieu',list(range(48,70)),20,'raw/glieu_wagon_icons.png',cols=6)
    sheet('glieu',list(range(76,101))+[102],20,'raw/glieu_76_102.png',cols=6)
    sheet('glieu',list(range(0,18)),20,'raw/glieu_0_17.png',cols=6)
    sheet('carte',list(range(1,152)),0,'raw/carte_tiles_1_151_pal0.png',cols=16,cell=(20,34))
    sheet('carte',list(range(155,192)),0,'raw/carte_155_191_pal0.png',cols=12,cell=(20,20))
    sheet('carte',list(range(198,207))+list(range(210,235))+[237]+list(range(239,248)),196,'raw/carte_198_247_pal196.png',cols=12,cell=(36,36))
