"""Readable infix view of reference-private/*-listing.json (ALIS bytecode).
Semantics assumed (to verify against alis-source): operand ops load acc;
opushacc pushes acc; binary ops compute acc = acc OP arg; with opile the
left operand is the popped value (opernames.c opile/readexec_opername_saveD7);
array ops (omaintc/tabchar) take the last index from acc and earlier ones from the stack."""
import json, sys, re
BIN={'oand':'&','oor':'|','oxor':'^','oadd':'+','osub':'-','omul':'*','odiv':'/','oegal':'==','odiff':'!=','oinf':'<','osup':'>','oinfeg':'<=','osupeg':'>=','omod':'%'}
def space(nm):
    # [osa]maintX = main-process array; [osa]dirtX = this process's own array.
    # suffix: tc = byte cells, ti = 16-bit cells ('w'), tp = strings ('p').
    base='main' if 'main' in nm else 'LOC' if 'loc' in nm else 'L'
    return base+{'i':'w','p':'p'}.get(nm[-1],'')
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
                    return f"{space(t['name'])}[{t['args'][0]:#06x}][{prev}][{acc}]"
                break
            if nm=='opushacc': st.append(acc); continue
            if nm in BIN:
                arg=it['args'][0]
                if arg['name']=='opile':
                    # opernames.c opile: D7 = old acc, D6 = popped value, so the
                    # operator computes (popped OP acc), not (acc OP popped).
                    acc=f"({st.pop() if st else '?'} {BIN[nm]} {acc})"; continue
                acc=f"({acc} {BIN[nm]} {fmt(arg,st)})"; continue
            if re.match(r'^[osa](main|dir|loc)t[a-z]$', nm):
                idx=acc; prev=st.pop() if st else '?'
                acc=f"{space(nm)}[{it['args'][0]:#06x}][{prev}][{idx}]"; continue
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
