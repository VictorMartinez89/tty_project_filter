"""cocotb TB de peripheral_sobel: maneja el bus femto (cs/addr/rd/wr/d_in/d_out)
como el CPU (pixel-a-pixel, polling) y valida modo COMPASS y modo CANNY vs golden."""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import numpy as np

A_CTRL,A_IMGW,A_LOW,A_HIGH,A_PIXEL,A_STATUS,A_RESULT = 0x00,0x04,0x08,0x0C,0x10,0x14,0x18

async def bus_write(d, a, val):
    await FallingEdge(d.clk); d.cs.value=1; d.addr.value=a; d.d_in.value=val; d.wr.value=1; d.rd.value=0
    await FallingEdge(d.clk); d.cs.value=0; d.wr.value=0
async def bus_read(d, a):
    await FallingEdge(d.clk); d.cs.value=1; d.addr.value=a; d.rd.value=1; d.wr.value=0
    await RisingEdge(d.clk); await Timer(1,"ns"); v=int(d.d_out.value)
    await FallingEdge(d.clk); d.cs.value=0; d.rd.value=0
    return v

async def init(d, mode, W, low=0, high=0):
    cocotb.start_soon(Clock(d.clk, 10, units="ns").start())
    d.reset.value=1; d.cs.value=0; d.rd.value=0; d.wr.value=0; d.addr.value=0; d.d_in.value=0
    await FallingEdge(d.clk); await FallingEdge(d.clk); d.reset.value=0
    await bus_write(d, A_IMGW, W)
    await bus_write(d, A_LOW, low); await bus_write(d, A_HIGH, high)
    await bus_write(d, A_CTRL, mode | 2)        # set mode + frame_reset pulse

async def feed_and_collect(d, img):
    H,W = img.shape; res=[]
    for px in img.flatten().tolist():
        await bus_write(d, A_PIXEL, int(px))
        for _ in range(5):                       # poll STATUS (latencia corta)
            if (await bus_read(d, A_STATUS)) & 1:
                res.append(await bus_read(d, A_RESULT)); break
    return res

# ---------- goldens ----------
KER={"N":[[1,2,1],[0,0,0],[-1,-2,-1]],"NE":[[2,1,0],[1,0,-1],[0,-1,-2]],"E":[[1,0,-1],[2,0,-2],[1,0,-1]],
     "SE":[[0,-1,-2],[1,0,-1],[2,1,0]],"S":[[-1,-2,-1],[0,0,0],[1,2,1]],"SW":[[-2,-1,0],[-1,0,1],[0,1,2]],
     "W":[[-1,0,1],[-2,0,2],[-1,0,1]],"NW":[[0,1,2],[-1,0,1],[-2,-1,0]]}
ORD=["N","NE","E","SE","S","SW","W","NW"]
def compass_golden(img):
    H,W=img.shape; out=[]
    for cr in range(1,H-1):
        for cc in range(1,W-1):
            win=img[cr-1:cr+2,cc-1:cc+2]
            raw=[abs(int((win*np.array(KER[k])).sum())) for k in ORD]
            dd=int(np.argmax(raw)); out.append((dd<<8)|min(255,raw[dd]))
    return out

def cgrad(img,r,c):
    g=lambda i,j:int(img[i,j])
    gx=(g(r-1,c+1)-g(r-1,c-1))+2*(g(r,c+1)-g(r,c-1))+(g(r+1,c+1)-g(r+1,c-1))
    gy=(g(r+1,c-1)-g(r-1,c-1))+2*(g(r+1,c)-g(r-1,c))+(g(r+1,c+1)-g(r-1,c+1))
    ax,ay=abs(gx),abs(gy); ay8=ay<<8
    q=0 if ay8<ax*106 else (2 if ay8>ax*618 else (1 if (gx<0)==(gy<0) else 3))
    return ax+ay,q
def ccls(img,r,c,LOW,HIGH):
    m,q=cgrad(img,r,c); mg=lambda i,j:cgrad(img,i,j)[0]
    n1,n2=[(mg(r,c+1),mg(r,c-1)),(mg(r-1,c+1),mg(r+1,c-1)),(mg(r-1,c),mg(r+1,c)),(mg(r-1,c-1),mg(r+1,c+1))][q]
    sup=m if (m>=n1 and m>=n2) else 0
    return 2 if sup>=HIGH else (1 if sup>=LOW else 0)
def canny_golden(img,LOW,HIGH):
    H,W=img.shape; out=[]
    for cr in range(3,H-3):
        for cc in range(3,W-3):
            c0=ccls(img,cr,cc,LOW,HIGH)
            e=1 if c0==2 else (int(any(ccls(img,cr+dr,cc+dc,LOW,HIGH)==2 for dr in(-1,0,1) for dc in(-1,0,1) if(dr or dc))) if c0==1 else 0)
            out.append((c0<<1)|e)
    return out

@cocotb.test()
async def compass_mode(dut):
    H=W=8
    r=np.arange(H)[:,None]; c=np.arange(W)[None,:]
    img=((r*37+c*53+r*c*11)%256).astype(int)
    await init(dut, 0, W)
    got=await feed_and_collect(dut, img); exp=compass_golden(img)
    assert len(got)==len(exp), f"compass: {len(got)} != {len(exp)}"
    ok=sum(g==e for g,e in zip(got,exp))
    dut._log.info(f"COMPASS via bus: {ok}/{len(exp)} ({100*ok/len(exp):.1f}%)")
    assert ok==len(exp)
    dut._log.info("PERIPHERAL_SOBEL compass: ALL TESTS PASSED")

@cocotb.test()
async def canny_mode(dut):
    H=W=14; LOW,HIGH=40,200
    img=np.zeros((H,W),int)
    for i in range(H):
        for j in range(W): img[i,j]=min(255,6*i+(120 if i>=9 else 0))
    await init(dut, 1, W, LOW, HIGH)
    got=await feed_and_collect(dut, img); exp=canny_golden(img,LOW,HIGH)
    assert len(got)==len(exp), f"canny: {len(got)} != {len(exp)}"
    ok=sum(g==e for g,e in zip(got,exp))
    dut._log.info(f"CANNY via bus: {ok}/{len(exp)} ({100*ok/len(exp):.1f}%)")
    assert ok==len(exp)
    dut._log.info("PERIPHERAL_SOBEL canny: ALL TESTS PASSED")
