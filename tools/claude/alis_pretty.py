"""Readable infix view of reference-private/*-listing.json (ALIS bytecode).
Semantics assumed (to verify against alis-source): operand ops load acc;
opushacc pushes acc; binary ops compute acc = acc OP arg; opile pops;
array ops (omaintc/tabchar) take the last index from acc and earlier ones from the stack."""
import json, sys, re
BIN={'oand':'&','oor':'|','oxor':'^','oadd':'+','osub':'-','omul':'*','odiv':'/','oegal':'==','odiff':'!=','oinf':'<','osup':'>','oinfeg':'<=','osupeg':'>=','omod':'%'}
def loc(n,w): return f"L{n:#04x}{w}"
def fmt(node, stack=None):
    n=node['name']; a=node.get('args',[])
    if n in('oeval','seval'):
        st=[]; acc=None
        for k,it in enumerate(a):
            nm=it['name']
            if nm=='ofin':
                if n=='seval' and k+1<len(a):
                    t=a[k+1]; prev=st.pop() if st else '?'
                    return f"main[{t['args'][0]:#06x}][{prev}][{acc}]"
                break
            if nm=='opushacc': st.append(acc); continue
            if nm in BIN:
                arg=it['args'][0]
                rhs = (st.pop() if st else '?') if arg['name']=='opile' else fmt(arg,st)
                acc=f"({acc} {BIN[nm]} {rhs})"; continue
            if re.match(r'^[osa](main|dir|loc)t[a-z]$', nm):
                idx=acc; prev=st.pop() if st else '?'
                acc=f"main[{it['args'][0]:#06x}][{prev}][{idx}]"; continue
            if not it.get('args') and nm not in ('oimmb','oimmw','oimml'):
                acc=f"{nm[1:]}({acc})"; continue
            acc=fmt(it,st)
        return acc
    if n in('odirb','sdirb','adirb'): return loc(a[0],'b')
    if n in('odirw','sdirw','adirw'): return loc(a[0],'w')
    if n in('oimmb','oimmw','oimml'): return str(a[0])
    if n=='olocw': return f"LOC{a[0]}"
    if re.match(r'^[osa]main[bwl]$', n): return f"main+{a[0]:#06x}"
    if n=='oneg': return f"-{fmt(a[0])}" if a else '-acc'
    if n in('oabs',): return f"abs(acc)"
    return n+(str([fmt(x) if isinstance(x,dict) else x for x in a]) if a else '')
def show(path, lo, hi):
    d=json.load(open(path))
    for i in sorted(d['instructions'], key=lambda i:i['offset']):
        o=i['offset']
        if not lo<=o<hi: continue
        n=i['name']; a=i.get('args',[])
        parts=[fmt(x) if isinstance(x,dict) else str(x) for x in a]
        tg=' -> '+','.join(hex(t) for t in i['targets']) if i['targets'] else ''
        if n=='cstore' and len(parts)==2: s=f"{parts[1]} = {parts[0]}"
        elif n=='cadd' and len(parts)==2: s=f"{parts[1]} += {parts[0]}"
        elif n=='csub' and len(parts)==2: s=f"{parts[1]} -= {parts[0]}"
        elif n=='ceval': s=f"acc = {parts[0]}"
        else: s=f"{n} {' '.join(parts)}"
        print(f"{o:#06x}  {s}{tg}")
if __name__=='__main__':
    show(sys.argv[1], int(sys.argv[2],16), int(sys.argv[3],16))
