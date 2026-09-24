## How it works

Canny-78, the MNIST recogniser of an MSc thesis (UNAL): a streaming Canny 1-hop edge detector
(Gaussian 3x3 -> Sobel -> dual threshold 90/32 -> 1-hop hysteresis) feeds 128 counters (16 zones x 8
gradient octants). 78 selected features go through a signed 4-bit linear classifier (two classes per
pass), then argmax and a reject rule (edge density and score margin). 97.22 % on the 10 000 MNIST test
images, verified 10000/10000 against the golden model (this variant trims the feature memory to 168x9).

## How to test

Stream a 28x28 window in raster order on ui_in with uio[0]=in_valid high, then 8 extra samples to
flush the pipeline. About 778 cycles later `done` pulses on uo[5]: uo[3:0] is the digit, uo[4]=1 if
the chip commits to it (0 = NOTHING).
