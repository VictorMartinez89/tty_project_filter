## How it works

Most vision chips **draw**. This one **recognises**: its output is not an image, it is four bits
and one bit that says *"I believe it"*.

A 28×28 window of 8-bit luma enters one pixel per clock. Four stages follow, and none of them
contains a multiplier:

1. **Canny, one hop.** Gaussian, Sobel, then a DUAL threshold that labels each pixel strong,
   weak or flat, and a 3×3 hysteresis window that promotes a weak pixel if it touches a strong
   neighbour. The magnitude is the L1
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

**The two thresholds are hardwired to 90 and 32**, which are the values the firmware writes in the
SoC version and the ones these weights were trained with. The version where a RISC-V core writes
them at run time — both in a single 32-bit store, so there is never an instant with the new high
threshold and the old low one — does not fit: it needs ≈21 600 cells against the ≈18 800 that a 8×2
tile holds.

**There is no camera front-end either.** The chip expects the 28×28 window already cropped; building
it from a 640×480 sensor costs another ≈5 500 cells.

Measured on MNIST (60 000 train / 10 000 test, 4-bit weights): **92.0 %** accuracy, and **98.7 %**
precision on the digits it chooses to answer. The same front-end, with a RISC-V writing the
thresholds, recognised **9 of 10** digits in front of a real OV7670 camera on an iCE40UP5K.

The extra line buffer is what this front-end buys: the Sobel version sits on a narrow optimum — its
accuracy moves 5.79 points across the useful threshold range — while this one moves 0.90. It is not
more accurate; it is **insensitive**.

## How to test

Drive `ui_in` with the 784 pixels of a 28×28 window in raster order, holding `uio_in[0]`
(`in_valid`) high. Send the image **three times**: the line buffers start empty, so the first pass
primes them, the second is the one that counts, and the third drains the pipeline (this front-end has three line buffers instead of two, so it needs more flushing). After the last
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
