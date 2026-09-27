import json,sys,glob,os
targets=[int(x,0) for x in sys.argv[1].split(',')]
def walk(o,hits):
    if isinstance(o,dict):
        nm=o.get('name','')
        a=o.get('args',[])
        if 'main' in nm and a and isinstance(a[0],int) and a[0] in targets:
            hits.append(nm)
        for v in o.values(): walk(v,hits)
    elif isinstance(o,list):
        for v in o: walk(v,hits)
for p in sorted(glob.glob(sys.argv[2]+'/*.json')):
    d=json.load(open(p))
    for i in d['instructions']:
        h=[]; walk(i.get('args',[]),h)
        if h: print(os.path.basename(p)[:-5], hex(i['offset']), i['name'], sorted(set(h)))
