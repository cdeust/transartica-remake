"""Static replay of TIME heading rules (0x1444..0x1918) and candidate step (0x1a34) on CARTE.FIC.
Hypothesis under test, not a port: prints the route a player train would follow."""
import sys
from pathlib import Path
raw=Path(__file__).resolve().parents[2].joinpath('reference-private/CARTE.FIC').read_bytes()
W,H=160,73
# TABLE 0x12ea..0x137c: unconditional tile writes when a new game is initialised.
TABLE_INIT={(54,5):-121,(144,4):-121,(6,9):64,(70,19):-117,(25,24):63,(134,40):63,(94,37):64,(71,54):-121,(139,57):64,(83,67):63,(116,55):70,(114,55):81}
def tile(x,y):
    if (x,y) in TABLE_INIT: return TABLE_INIT[(x,y)]
    v=raw[73*x+y]; return v-256 if v>127 else v
DELTA={1:(-1,1),2:(0,1),3:(1,1),4:(-1,0),5:(0,0),6:(1,0),7:(-1,-1),8:(0,-1),9:(1,-1)}
CURVE={'A':{6:3,7:4},'B':{9:6,4:1},'C':{3:6,4:7},'D':{6:9,1:4},'E':{8:7,3:2},'F':{8:9,1:2},'G':{2:1,9:8},'H':{2:3,7:8}}
SWITCH={18:(6,9,1,4),20:(4,7,3,6),22:(6,3,7,4),24:(4,1,9,6),26:(2,3,7,8),28:(2,1,9,8),30:(8,9,1,2),32:(8,7,3,2)}
CASES={6:'A',7:'B',8:'C',9:'D',10:'E',11:'F',12:'G',13:'H',42:'A',43:'B',44:'D',45:'C',46:'F',47:'E',48:'H',51:'A',55:'G',57:'B'}
EVENTS={-120,-116,34,35,36,37,65,67,69,78,79,114}
def turn(t,h,diverge_odd=True):
    a=abs(t)
    if a in CASES: return CURVE[CASES[a]].get(h,h)
    base=a-(a%2)
    if base in SWITCH:
        trig,div,other,other_to=SWITCH[base]
        if h==trig: return div if a%2==1 else h
        if h==other: return other_to
    return h
def run(x,y,h,steps=400):
    path=[]
    for _ in range(steps):
        t=tile(x,y)
        path.append((x,y,h,t))
        if -105<t<0: return path,'blocked negative tile'
        if t in EVENTS: return path,f'event tile {t}'
        h=turn(t,h)
        dx,dy=DELTA[h]; x=(x+dx)%W; y+=dy
        if not 0<=y<H: return path,'off map'
        if tile(x,y)==0: path.append((x,y,h,0)); return path,'rail ends (tile 0)'
    return path,'step limit'
if __name__=='__main__':
    x,y,h=map(int,sys.argv[1:4]) if len(sys.argv)>3 else (12,62,6)
    p,why=run(x,y,h)
    for s in p: print(s)
    print('STOP:',why,'after',len(p),'cells')
