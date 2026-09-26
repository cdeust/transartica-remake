"""Explore every state reachable from the start, taking both branches at each switch.
Counts how traversals end; a correct heading table should never run onto tile 0."""
import sys, csv, collections
sys.path.insert(0,'tools/claude')
from sim_route import tile, DELTA, CASES, CURVE, SWITCH, EVENTS, W, H
def successors(x,y,h):
    t=tile(x,y); a=abs(t); outs=set()
    base=a-(a%2)
    if a in CASES: outs.add(CURVE[CASES[a]].get(h,h))
    elif base in SWITCH:
        trig,div,other,oto=SWITCH[base]
        if h==trig: outs|={h,div}
        elif h==other: outs.add(oto)
        else: outs.add(h)
    else: outs.add(h)
    return outs
start=(12,62,6); seen={start}; q=[start]; ends=collections.Counter(); where=collections.defaultdict(list)
while q:
    x,y,h=q.pop()
    t=tile(x,y)
    if -105<t<0: ends['blocked neg']+=1; where['neg'].append((x,y,t)); continue
    if t in EVENTS: ends[f'event {t}']+=1; where['ev'].append((x,y,t)); continue
    for nh in successors(x,y,h):
        dx,dy=DELTA[nh]; nx=(x+dx)%W; ny=y+dy
        if not 0<=ny<H: ends['off map']+=1; continue
        if tile(nx,ny)==0: ends['rail ends']+=1; where['end'].append((x,y,h,t,nh)); continue
        s=(nx,ny,nh)
        if s not in seen: seen.add(s); q.append(s)
cells={(x,y) for x,y,h in seen}
print('reachable states',len(seen),'cells',len(cells))
print(dict(ends))
print('rail-end samples',where['end'][:15])
print('event tiles hit',sorted(set(where['ev']))[:60])
print('negative hit',sorted(set(where['neg']))[:30])
nonzero=sum(1 for x in range(W) for y in range(H) if tile(x,y)!=0)
print('nonzero map cells',nonzero)
