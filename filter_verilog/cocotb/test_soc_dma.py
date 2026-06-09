"""cocotb: integracion DMA+arbitro al SoC. El TB = CPU: precarga imagen en RAM,
programa el DMA y lo dispara; el arbitro le da el bus al DMA (cpu_stall=1); al
terminar, el CPU lee resultados de la RAM. Valida ambos modos vs golden."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import numpy as np

async def cpu_w(d,a,v):
    await FallingEdge(d.clk); d.cpu_req.value=1; d.cpu_we.value=1; d.cpu_addr.value=a; d.cpu_wdata.value=int(v)
    await FallingEdge(d.clk); d.cpu_req.value=0; d.cpu_we.value=0
async def cpu_r(d,a):
    await FallingEdge(d.clk); d.cpu_req.value=1; d.cpu_we.value=0; d.cpu_addr.value=a
    await RisingEdge(d.clk); await Timer(1,"ns"); v=int(d.cpu_rdata.value)
    await FallingEdge(d.clk); d.cpu_req.value=0
    return v

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
    for s in ("reset","cpu_req","cpu_we","cpu_addr","cpu_wdata","dma_start","dma_mode","src_addr","dst_addr","npx","img_w","low","high"):
        getattr(d,s).value=0
    d.reset.value=1; await FallingEdge(d.clk); await FallingEdge(d.clk); d.reset.value=0

async def run(d, img, mode, lo=0, hi=0):
    H,W=img.shape; npx=H*W; dst=npx
    for i,px in enumerate(img.flatten().tolist()): await cpu_w(d, i, px)   # CPU precarga RAM
    d.dma_mode.value=mode; d.src_addr.value=0; d.dst_addr.value=dst; d.npx.value=npx
    d.img_w.value=W; d.low.value=lo; d.high.value=hi
    await FallingEdge(d.clk); d.dma_start.value=1
    await FallingEdge(d.clk); d.dma_start.value=0
    cyc=0; stalled=0
    while int(d.dma_done.value)==0:
        await RisingEdge(d.clk); cyc+=1
        if int(d.cpu_stall.value)==1 or int(d.dma_req.value)==1: stalled=1
        if cyc>10*npx: break
    rc=int(d.rescount.value)
    res=[await cpu_r(d, dst+k) for k in range(rc)]   # CPU lee resultados de RAM
    return res, rc, cyc, stalled

@cocotb.test()
async def soc_compass(dut):
    await setup(dut)
    H=W=8; r=np.arange(H)[:,None];c=np.arange(W)[None,:]; img=((r*37+c*53+r*c*11)%256).astype(int)
    res,rc,cyc,stalled=await run(dut,img,0); exp=compass_golden(img)
    assert rc==len(exp), f"rescount {rc} != {len(exp)}"
    ok=sum(a==b for a,b in zip(res,exp))
    dut._log.info(f"SOC DMA COMPASS: {ok}/{len(exp)} ({100*ok/len(exp):.1f}%)  {cyc} ciclos  cpu_stall_visto={bool(stalled)}")
    assert ok==len(exp); dut._log.info("SOC DMA COMPASS: PASSED")

@cocotb.test()
async def soc_canny(dut):
    await setup(dut)
    H=W=14;LO,HI=40,200; img=np.zeros((H,W),int)
    for i in range(H):
        for j in range(W): img[i,j]=min(255,6*i+(120 if i>=9 else 0))
    res,rc,cyc,stalled=await run(dut,img,1,LO,HI); exp=canny_golden(img,LO,HI)
    assert rc==len(exp), f"rescount {rc} != {len(exp)}"
    ok=sum(a==b for a,b in zip(res,exp))
    dut._log.info(f"SOC DMA CANNY: {ok}/{len(exp)} ({100*ok/len(exp):.1f}%)  {cyc} ciclos  cpu_stall_visto={bool(stalled)}")
    assert ok==len(exp); dut._log.info("SOC DMA CANNY: PASSED")
