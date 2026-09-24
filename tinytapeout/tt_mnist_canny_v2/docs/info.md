## How it works

The MNIST digit recogniser of an MSc thesis (UNAL), version 2. A streaming Canny 1-hop edge detector
(Gaussian 3x3 -> Sobel -> dual threshold 90/32 -> 1-hop hysteresis) feeds 32 counters (4 quadrants x 8
gradient octants); a 40-feature spatial pyramid goes through 400 signed 4-bit MACs, argmax and a reject
rule. **94.20 %** on the 10 000 MNIST test images, verified 10000/10000 against the golden model
(counters, edge count and verdict).

v2 vs v1: extractor latency fixed to 3*(W+1) = 87, two synchronisation bugs fixed, the 10 biases
recalibrated on the training set (92.46 % -> 94.20 %, same weights, same area), and `clr` generated
internally one cycle after `done`.

## How to test

Stream a 28x28 window in raster order on ui_in, pulsing uio[0] (in_valid) for one cycle per pixel
with **at least 2 idle cycles between pixels**, then 16 extra samples. When `done` pulses on uo[5],
uo[3:0] is the digit and uo[4]=1 if the chip commits to it (0 = NOTHING).
