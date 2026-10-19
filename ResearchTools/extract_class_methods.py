#!/usr/bin/env python3
"""Extract methods for specified ObjC class from original thin arm64 Mach-O.
Known-layout reader; read-only. Class address must come from the matching Mach-O symbol.
"""
import argparse
import json
import struct
from pathlib import Path

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--macho",type=Path,required=True)
    p.add_argument("--class-address",type=lambda x:int(x,0),required=True)
    p.add_argument("--expected-class",required=True)
    a=p.parse_args()
    data=a.macho.read_bytes()
    if struct.unpack_from("<I",data,0)[0]!=0xfeedfacf: p.error("requires little-endian thin mach-o64")
    # Image has equal VM and file offsets for the relevant __DATA class structures.
    # Validate against segment mappings before dereferencing offsets.
    segments=[]
    off=32
    for _ in range(struct.unpack_from("<I",data,16)[0]):
        cmd,size=struct.unpack_from("<II",data,off)
        if size<8 or off+size>len(data): p.error("bad load commands")
        if cmd==0x19:
            vm,sz,fo,fs=struct.unpack_from("<QQQQ",data,off+24)
            segments.append((vm,vm+min(sz,fs),fo))
        off+=size
    def offset(addr,n=1):
        for lo,hi,fo in segments:
            if lo<=addr and addr+n<=hi:return fo+addr-lo
        raise ValueError(f"unmapped address: {addr:#x}")
    def u64(addr):return struct.unpack_from("<Q",data,offset(addr,8))[0]
    def i32(addr):return struct.unpack_from("<i",data,offset(addr,4))[0]
    def cstr(addr):
        fo=offset(addr)
        end=data.find(b"\0",fo,min(len(data),fo+1024))
        if end<0:raise ValueError("unterminated string")
        return data[fo:end].decode("utf-8")
    # DYLD_CHAINED_PTR_64_OFFSET data pointer target (validated for this X v12.25 binary).
    target=lambda value:value&((1<<36)-1)
    ro=target(u64(a.class_address+32))
    name=cstr(target(u64(ro+24)))
    if name!=a.expected_class:p.error(f"class mismatch: {name}")
    lst=target(u64(ro+32))
    head,count=struct.unpack_from("<II",data,offset(lst,8))
    if head&0x80000000==0 or (head&0xffff)!=12 or count>1000:p.error("unexpected method list format")
    result=[]
    for i in range(count):
        entry=lst+8+12*i
        nameaddr=entry+i32(entry)
        try:selector=cstr(nameaddr)
        except (ValueError,UnicodeError):
            selector=cstr(target(u64(nameaddr)))
        types=cstr(entry+4+i32(entry+4))
        imp=entry+8+i32(entry+8)
        result.append({"selector":selector,"types":types,"imp":f"0x{imp:X}"})
    print(json.dumps({"class":name,"class_address":hex(a.class_address),"method_list":hex(lst),"methods":result},ensure_ascii=False,indent=2))
if __name__=="__main__":main()
