"""cocotb TB de peripheral_sobel_fb (FRAMEBUFFER/DMA): carga imagen a inbuf,
START, procesa autonomo a ~1px/ciclo, lee resultados. Valida ambos modos vs
golden y MIDE los ciclos (velocidad) frente a pixel-a-pixel."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import numpy as np

A_CTRL,A_IMGW,A_NPX,A_LOW,A_HIGH,A_WRPIX,A_START,A_RDRES = 0,4,8,0xC,0x10,0x14,0x18,0x1C

async def bw(d,a,v):
    await FallingEdge(d.clk); d.cs.value=1; d.addr.value=a; d.d_in.value=v; d.wr.value=1; d.rd.value=0
    await FallingEdge(d.clk); d.cs.value=0; d.wr.value=0
async def br(d,a):
    await FallingEdge(d.clk); d.cs.value=1; d.addr.value=a; d.rd.value=1; d.wr.value=0
    await Timer(1,"ns"); v=int(d.d_out.value)     # muestrear con rptr ACTUAL (combinacional)
    await RisingEdge(d.clk)                        # aqui rptr se auto-incrementa (RDRES)
    await FallingEdge(d.clk); d.cs.value=0; d.rd.value=0
    return v

KER={"N":[[1,2,1],[0,0,0],[-1,-2,-1]],"NE":[[2,1,0],[1,0,-1],[0,-1,-2]],"E":[[1,0,-1],[2,0,-2],[1,0,-1]],
     "SE":[[0,-1,-2],[1,0,-1],[2,1,0]],"S":[[-1,-2,-1],[0,0,0],[1,2,1]],"SW":[[-2,-1,0],[-1,0,1],[0,1,2]],
     "W":[[-1,0,1],[-2,0,2],[-1,0,1]],"NW":[[0,1,2],[-1,0,1],[-2,-1,0]]}
ORD=["N","NE","E","SE","S","SW","W","NW"]
def compass_golden(img):
    H,W=img.shape;o=[]
    for cr in range(1,H-1):
        for cc in range(1,W-1):
            win=img[cr-1:cr+2,cc-1:cc+2]; raw=[abs(int((win*np.array(KER[k])).sum())) for k in ORD]
            dd=int(np.argmax(raw)); o.append((dd<<8)|min(255,raw[dd]))
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
    d.reset.value=1;d.cs.value=0;d.rd.value=0;d.wr.value=0;d.addr.value=0;d.d_in.value=0
    await FallingEdge(d.clk);await FallingEdge(d.clk);d.reset.value=0

async def run_frame(d, img, mode, lo=0, hi=0):
    H,W=img.shape
    await bw(d,A_CTRL, mode|2)            # mode + clear (wptr=0)
    await bw(d,A_IMGW,W); await bw(d,A_NPX,H*W); await bw(d,A_LOW,lo); await bw(d,A_HIGH,hi)
    for px in img.flatten().tolist(): await bw(d,A_WRPIX,int(px))   # carga imagen
    await bw(d,A_START,1)
    cyc=0
    while True:
        st=await br(d,A_START)
        if st&1: break
        cyc+=1
        if cyc>4*H*W: break
    rescount=st>>1
    res=[await br(d,A_RDRES) for _ in range(rescount)]
    return res, rescount, cyc

@cocotb.test()
async def fb_compass(dut):
    await setup(dut)
    H=W=8; r=np.arange(H)[:,None];c=np.arange(W)[None,:]; img=((r*37+c*53+r*c*11)%256).astype(int)
    res,rc,cyc=await run_frame(dut,img,0); exp=compass_golden(img)
    assert rc==len(exp), f"rescount {rc} != {len(exp)}"
    ok=sum(a==b for a,b in zip(res,exp))
    dut._log.info(f"FB COMPASS: {ok}/{len(exp)} ({100*ok/len(exp):.1f}%)  procesado en ~{cyc} ciclos (8x8)")
    assert ok==len(exp); dut._log.info("FB COMPASS: PASSED")

@cocotb.test()
async def fb_canny(dut):
    await setup(dut)
    H=W=14;LO,HI=40,200; img=np.zeros((H,W),int)
    for i in range(H):
        for j in range(W): img[i,j]=min(255,6*i+(120 if i>=9 else 0))
    res,rc,cyc=await run_frame(dut,img,1,LO,HI); exp=canny_golden(img,LO,HI)
    assert rc==len(exp), f"rescount {rc} != {len(exp)}"
    ok=sum(a==b for a,b in zip(res,exp))
    dut._log.info(f"FB CANNY: {ok}/{len(exp)} ({100*ok/len(exp):.1f}%)  procesado en ~{cyc} ciclos (14x14)")
    assert ok==len(exp); dut._log.info("FB CANNY: PASSED")
