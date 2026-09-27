import sys; sys.path.insert(0,'.'); from compose import *
g=S('glieu'); P3=g.palette(20)
def banner(cv,menus):
    it=expand(g,19,0,50,27)
    for m in menus: it+=expand(g,m,0,10,0)
    paint(cv,it,P3,0,39)
def city(name,script,bgcomp,palidx,menus,extra=None):
    cv=blank(); s=S(script)
    banner(cv,menus)
    it=expand(s,bgcomp,0,100,0)
    if extra: it+=extra()
    paint(cv,it,s.palette(palidx),39,149)
    paste_panel(cv); save(cv,name,2)
city('decoded-city-town-type1.png','ville',4,5,[24,21])
city('decoded-city-commercial-type2.png','ville',1,2,[22,21])
city('decoded-city-garrison-type4.png','ville',7,8,[25,21])
city('decoded-city-mammothfair-type5.png','mamesc',1,2,[22,21])
city('decoded-city-slavemarket-type6.png','mamesc',4,5,[22,21])
u=S('usine')
city('decoded-city-industrial-workshop-type3.png','usine',1,2,[47],extra=lambda: expand(u,29+(12-4),0,50,0))
# trade list (commercial): grid 26 + sample goods icons in cells, transaction bar 23
def grid():
    it=expand(g,26,0,50,0)
    for k in range(10):
        it+=expand(g,31+k,31+(k%5)*64,10,149-(k//5)*27)
    return it
cv=blank(); banner(cv,[23]); paint(cv,grid(),S('ville').palette(2),39,149); paste_panel(cv); save(cv,'decoded-city-trade-list-layout.png',2)
# workshop wagon list 105 + wagon icons
def wl():
    it=expand(g,105,0,50,0)
    for k in range(8): it+=expand(g,48+k,31+(k%5)*64,10,150-(k//5)*25)
    return it
cv=blank(); banner(cv,[23]); paint(cv,wl(),u.palette(2),39,149); paste_panel(cv); save(cv,'decoded-city-workshop-list-layout.png',2)
# general map
c=S('carte'); cv=blank()
paint(cv,expand(c,193,0,50,0),c.palette(196),0,149); paste_panel(cv); save(cv,'decoded-general-map-screen.png',2)
# detailed map window at start
import mapr
w,h=0,0
cvm,W,H=mapr.render(2,57,20,10)
cv=blank()
for y in range(149):
    cv[y]=list(cvm[y][:320])
paste_panel(cv); save(cv,'decoded-detailed-map-screen-start.png',2)
# gare-atelier (mine)
mn=S('mine'); cv=blank()
paint(cv,expand(mn,1,0,100,0),mn.palette(2),0,149); paste_panel(cv); save(cv,'decoded-gare-atelier-mine-full.png',2)
cv=blank(); banner(cv,[73]); paint(cv,expand(mn,4,0,100,0),mn.palette(5),39,149); paste_panel(cv); save(cv,'decoded-gare-atelier-mine-109.png',2)
sc=S('scene3'); cv=blank(); paint(cv,expand(sc,2,0,100,0),sc.palette(1),0,149); paste_panel(cv); save(cv,'decoded-scene3-nomads.png',2)
print('done')
