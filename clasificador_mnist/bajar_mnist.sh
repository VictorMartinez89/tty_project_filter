#!/usr/bin/env bash
# bajar_mnist.sh — baja MNIST y lo deja en mnist.npz (no se versiona: ~11 MB, regenerable).
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"; cd "$AQUI"
BASE=https://ossci-datasets.s3.amazonaws.com/mnist
for f in train-images-idx3-ubyte train-labels-idx1-ubyte t10k-images-idx3-ubyte t10k-labels-idx1-ubyte; do
    [ -f $f.gz ] || curl -s -O $BASE/$f.gz
done
python3 - <<'PY'
import gzip, numpy as np
def img(p):
    with gzip.open(p) as f:
        assert int.from_bytes(f.read(4),'big') == 2051
        n,r,c = [int.from_bytes(f.read(4),'big') for _ in range(3)]
        return np.frombuffer(f.read(), np.uint8).reshape(n,r,c)
def lab(p):
    with gzip.open(p) as f:
        f.read(8); return np.frombuffer(f.read(), np.uint8)
np.savez_compressed('mnist.npz',
    X=img('train-images-idx3-ubyte.gz'),  y=lab('train-labels-idx1-ubyte.gz'),
    Xt=img('t10k-images-idx3-ubyte.gz'), yt=lab('t10k-labels-idx1-ubyte.gz'))
print('-> mnist.npz')
PY
