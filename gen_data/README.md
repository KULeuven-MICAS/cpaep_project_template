# Generate Data Script
This directory simply generates data into the `./data` directory.
Given sizes $M$, $K$, and $N$, the python scripts generates matrix A of size $M \times K$, matrix B of size $K \times N$, and multiplies the two matrices to produce output matrix O of size $M \times N$.

# How to use the script?
Simply invoke the command from the root of the repository:

```
python gen_data/gen_mkn.py --M 2 --K 2 --N 2 --out gen_data/data/.
```

There are different parameters that you can specify:

- `--M, --K, --N`: specify the matrix size M, K, and N.
- `--out`: target directory where you want to dump the outputs.
- `--seed`: (optional) fixed random seed.
- `--tokens-per-line`: (optional) how many 2-character hex tokens per line.
- `--dump_text`: (optional) also prints a .txt file of the matrices arranged in their row-col layout.