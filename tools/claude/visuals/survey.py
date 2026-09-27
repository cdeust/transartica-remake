import struct,sys,collections
def r16(d,o): return struct.unpack('>H',d[o:o+2])[0]
def r32(d,o): return struct.unpack('>i',d[o:o+4])[0]
for name in sys.argv[1:]:
    d=open(name,'rb').read()
    l=r32(d,0xe)
    n=r16(d,l+4)
    out=[]
    for i in range(n):
        a=r32(d,l)+l+i*4
        at=r32(d,a)+a
        t=d[at]
        if t<0x80:
            w=r16(d,at+2)+1;h=r16(d,at+4)+1
            out.append(f"{i}:{t:02x} {w}x{h}")
        else:
            out.append(f"{i}:{t:02x}/{d[at+1]}")
    print(name.split('/')[-1], len(d), 'res', n); print('  ', ' | '.join(out))
