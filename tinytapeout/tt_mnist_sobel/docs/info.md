## How it works

Most vision chips **draw**. This one **recognises**: its output is not an image, it is four bits
and one bit that says *"I believe it"*.

A 28×28 window of 8-bit luma enters one pixel per clock. Four stages follow, and none of them
contains a multiplier:

1. **Sobel 3×3.** Gaussian smoothing (`÷16` is a shift), then the gradient. The magnitude is the L1
   norm `|Gx|+|Gy|` — no square root. The orientation is the **octant**
   `⟨sgn Gy, sgn Gx, |Gy|>|Gx|⟩`: three comparisons instead of an `atan2`.
2. **Histogram.** The frame is split into 4 quadrants and each edge pixel increments one of
   **32 counters** (4 zones × 8 octants). Counters saturate rather than wrap.
3. **Spatial pyramid.** 40 features: the 32 counters plus 8 more for the whole image — and those 8
   are **not counted, they are derived** by summing the four quadrants, which are a partition. That
   is why the circuit stores 32 counters and not 40.
4. **Linear classifier.** 10 classes × 40 features = **400 signed 4-bit weights**, one MAC per
   clock, then `argmax`. The weights live in a combinational ROM: **they cost no flip-flops.**

Finally a **reject rule** decides whether to answer at all: the edge count must be plausible
(140–430) *and* the winner must beat the runner-up by more than 30. If either fails, `valido` stays
low and the chip reports **NOTHING** instead of guessing.

## Design notes

**The threshold is hardwired to 60**, which is the value the weights were trained with. The version
where a RISC-V core writes it at run time through a peripheral does not fit: it needs ≈21 600 cells
against the ≈18 800 that a 8×2 tile holds.

**There is no camera front-end either.** The chip expects the 28×28 window already cropped; building
it from a 640×480 sensor costs another ≈5 500 cells.

Measured on MNIST (60 000 train / 10 000 test, 4-bit weights): **91.0 %** accuracy, and **98.4 %**
precision on the digits it chooses to answer.

## How to test

Drive `ui_in` with the 784 pixels of a 28×28 window in raster order, holding `uio_in[0]`
(`in_valid`) high. Send the image **three times**: the line buffers start empty, so the first pass
primes them, the second is the one that counts, and the third drains the pipeline. After the last
pixel, wait ~600 clocks and read `uo_out`:

```
uo_out[3:0]  digit 0-9
uo_out[4]    valid   (0 = NOTHING)
uo_out[5]    done    (pulse)
```

Pulse `uio_in[1]` (`clr`) to clear the histogram before the next frame.

## External hardware

None required. Any source that can deliver 784 bytes — a microcontroller, an FPGA, or a camera
front-end that crops to 28×28 — will do.
