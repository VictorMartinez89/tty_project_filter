"""cocotb TB de filter_dma (DMA REAL desde RAM): precarga la imagen en srcram,
programa src/dst/npx/modo/umbrales, START. El DMA lee de RAM, filtra y escribe a
dstram SIN intervencion del CPU por pixel. Valida ambos modos vs golden + mide ciclos."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import numpy as np

async def ram_write(d, a, v):
    await FallingEdge(d.clk); d.pl_we.value=1; d.pl_addr.value=a; d.pl_data.value=int(v)
async def ram_read(d, a):
    d.rb_addr.value=a; await RisingEdge(d.clk); await Timer(1,"ns"); return int(d.rb_data.value)

KER={"N":[[1,2,1],[0,0,0],[-1,-2,-1]],"NE":[[2,1,0],[1,0,-1],[0,-1,-2]],"E":[[1,0,-1],[2,0,-2],[1,0,-1]],
     "SE":[[0,-1,-2],[1,0,-1],[2,1,0]],"S":[[-1,-2,-1],[0,0,0],[1,2,1]],"SW":[[-2,-1,0],[-1,0,1],[0,1,2]],
     "W":[[-1,0,1],[-2,0,2],[-1,0,1]],"NW":[[0,1,2],[-1,0,1],[-2,-1,0]]}
ORD=["N","NE","E","SE","S","SW","W","NW"]
def compass_golden(img):
    H,W=img.shape;o=[]
    for cr in range(1,H-1):
        for cc in range(1,W-1):
            win=img[cr-1:cr+2,cc-1:cc+2];raw=[abs(int((win*np.array(KER[k])).sum())) for k in ORD]
            dd=int(np.argmax(raw));o.append((dd<<8)|min(255,raw[dd]))
    return o
def cgrad(img,r,c):
    g=lambda i,j:int(img[i,j])
    gx=(g(r-1,c+1)-g(r-1,c-1))+2*(g(r,c+1)-g(r,c-1))+(g(r+1,c+1)-g(r+1,c-1))
    gy=(g(r+1,c-1)-g(r-1,c-1))+2*(g(r+1,c)-g(r-1,c))+(g(r+1,c+1)-g(r-1,c+1))
    ax,ay=abs(gx),abs(gy);ay8=ay<<8
    return ax+ay,(0 if ay8<ax*106 else (2 if ay8>ax*618 else (1 if (gx<0)==(gy<0) else 3)))
def ccls(img,r,c,LO,HI):
    m,q=cgrad(img,r,c);mg=lambda i,j:cgrad(img,i,j)[0]
    n1,n2=[(mg(r,c+1),mg(r,c-1)),(mg(r-1,c+1),mg(r+1,c-1)),(mg(r-1,c),mg(r+1,c)),(mg(r-1,c-1),mg(r+1,c+1))][q]
    sup=m if (m>=n1 and m>=n2) else 0
    return 2 if sup>=HI else (1 if sup>=LO else 0)
def canny_golden(img,LO,HI):
    H,W=img.shape;o=[]
    for cr in range(3,H-3):
        for cc in range(3,W-3):
            c0=ccls(img,cr,cc,LO,HI)
            e=1 if c0==2 else (int(any(ccls(img,cr+dr,cc+dc,LO,HI)==2 for dr in(-1,0,1) for dc in(-1,0,1) if(dr or dc))) if c0==1 else 0)
            o.append((c0<<1)|e)
    return o

async def setup(d):
    cocotb.start_soon(Clock(d.clk,10,units="ns").start())
    for s in ("reset","start","mode","src_addr","dst_addr","npx","img_w","low","high","pl_we","pl_addr","pl_data","rb_addr"):
        getattr(d,s).value=0
    d.reset.value=1
    await FallingEdge(d.clk); await FallingEdge(d.clk); d.reset.value=0

async def run(d, img, mode, lo=0, hi=0):
    H,W=img.shape; npx=H*W
    flat=img.flatten().tolist()
    for i,px in enumerate(flat): await ram_write(d, i, px)       # precargar srcram (1/ciclo)
    await FallingEdge(d.clk); d.pl_we.value=0
    d.mode.value=mode; d.src_addr.value=0; d.dst_addr.value=0; d.npx.value=npx
    d.img_w.value=W; d.low.value=lo; d.high.value=hi
    await FallingEdge(d.clk); d.start.value=1
    await FallingEdge(d.clk); d.start.value=0
    cyc=0
    while int(d.done.value)==0:
        await RisingEdge(d.clk); cyc+=1
        if cyc>8*npx: break
    rc=int(d.rescount.value)
    res=[await ram_read(d, k) for k in range(rc)]
    return res, rc, cyc

@cocotb.test()
async def dma_compass(dut):
    await setup(dut)
    H=W=8; r=np.arange(H)[:,None];c=np.arange(W)[None,:]; img=((r*37+c*53+r*c*11)%256).astype(int)
    res,rc,cyc=await run(dut,img,0); exp=compass_golden(img)
    assert rc==len(exp), f"rescount {rc} != {len(exp)}"
    ok=sum(a==b for a,b in zip(res,exp))
    dut._log.info(f"DMA COMPASS: {ok}/{len(exp)} ({100*ok/len(exp):.1f}%)  procesado en {cyc} ciclos ({H*W}px desde RAM)")
    assert ok==len(exp); dut._log.info("DMA COMPASS: PASSED")

@cocotb.test()
async def dma_canny(dut):
    await setup(dut)
    H=W=14;LO,HI=40,200; img=np.zeros((H,W),int)
    for i in range(H):
        for j in range(W): img[i,j]=min(255,6*i+(120 if i>=9 else 0))
    res,rc,cyc=await run(dut,img,1,LO,HI); exp=canny_golden(img,LO,HI)
    assert rc==len(exp), f"rescount {rc} != {len(exp)}"
    ok=sum(a==b for a,b in zip(res,exp))
    dut._log.info(f"DMA CANNY: {ok}/{len(exp)} ({100*ok/len(exp):.1f}%)  procesado en {cyc} ciclos ({H*W}px desde RAM)")
    assert ok==len(exp); dut._log.info("DMA CANNY: PASSED")
