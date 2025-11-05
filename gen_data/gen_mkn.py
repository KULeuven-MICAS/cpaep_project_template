import numpy as np
import argparse
from pathlib import Path
from typing import Tuple, Optional

def _to_hex_tokens(arr: np.ndarray, width_bits: int) -> np.ndarray:
    """
    Convert a signed integer array into two's-complement hex tokens (uppercase)
    with fixed width (e.g., 8 bits -> 2 hex chars, 32 bits -> 8 hex chars).
    """
    if width_bits == 8:
        u = arr.astype(np.uint8, copy=False)
        width = 2
    elif width_bits == 32:
        u = arr.astype(np.uint32, copy=False)
        width = 8
    else:
        raise ValueError("Only 8 or 32 bits are supported")
    # Format each element as fixed-width uppercase hex without '0x'
    return np.vectorize(lambda x: f"{int(x):0{width}X}")(u)

def _save_hex_file(tokens: np.ndarray, path: Path, tokens_per_line: int = 1) -> None:
    """
    Save tokens (1D array of hex strings) to a file with tokens_per_line per row.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    if tokens_per_line <= 0:
        # one token per line
        with path.open("w") as f:
            for t in tokens:
                f.write(f"{t}\n")
        return

    lines = []
    for i in range(0, len(tokens), tokens_per_line):
        lines.append(" ".join(tokens[i:i+tokens_per_line]))
    path.write_text("\n".join(lines) + "\n")

def _save_int_file(arr: np.ndarray, path: Path) -> None:
    """
    Save integer matrix to .txt in row-major form.
    Values are space-separated, one row per line.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [" ".join(str(int(x)) for x in row) for row in arr]
    path.write_text("\n".join(lines) + "\n")


def generate_gemm_hex(
    M: int,
    K: int,
    N: int,
    a_range: Tuple[int, int] = (-128, 127),
    b_range: Tuple[int, int] = (-128, 127),
    seed: Optional[int] = None,
    out_dir: str = ".",
    a_filename: str = "A.hex",
    b_filename: str = "B.hex",
    o_filename: str = "O.hex",
    tokens_per_line: int = 1,
    dump_txt: bool = False,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Generate random int8 matrices A (MxK), B (KxN),
    compute O = A @ B with int32 accumulation, and write hex files.

    Returns (A, B, O) as numpy arrays with dtypes int8, int8, int32.
    """
    if seed is not None:
        np.random.seed(seed)

    a_lo, a_hi = a_range
    b_lo, b_hi = b_range
    if not (-128 <= a_lo <= 127 and -128 <= a_hi <= 127):
        raise ValueError("a_range must fit in int8 [-128, 127]")
    if not (-128 <= b_lo <= 127 and -128 <= b_hi <= 127):
        raise ValueError("b_range must fit in int8 [-128, 127]")

    # randint high is exclusive → add 1
    A = np.random.randint(a_lo, a_hi + 1, size=(M, K), dtype=np.int16).astype(np.int8)
    B = np.random.randint(b_lo, b_hi + 1, size=(K, N), dtype=np.int16).astype(np.int8)

    # int32 accumulation to avoid overflow
    O = (A.astype(np.int32) @ B.astype(np.int32)).astype(np.int32)

    # Flatten row-major and convert to hex tokens (two's complement)
    A_tokens = _to_hex_tokens(A.ravel(order="C"), 8)   # 2 hex chars per int8
    B_tokens = _to_hex_tokens(B.ravel(order="C"), 8)
    O_tokens = _to_hex_tokens(O.ravel(order="C"), 32)  # 8 hex chars per int32

    out_dir = Path(out_dir)

    # --- Write hex ---
    _save_hex_file(A_tokens, out_dir / a_filename, tokens_per_line)
    _save_hex_file(B_tokens, out_dir / b_filename, tokens_per_line)
    _save_hex_file(O_tokens, out_dir / o_filename, tokens_per_line)

    # --- Write integer txt representations (sanity check files) ---
    if dump_txt:
      _save_int_file(A, out_dir / (Path(a_filename).stem + ".txt"))
      _save_int_file(B, out_dir / (Path(b_filename).stem + ".txt"))
      _save_int_file(O, out_dir / (Path(o_filename).stem + ".txt"))


    return A, B, O




if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="Generate A.hex, B.hex, and O.hex for GEMM (A[M×K], B[K×N], O[M×N])."
    )

    parser.add_argument("--M", type=int, required=True, help="Rows of A / O (M).")
    parser.add_argument("--K", type=int, required=True, help="Inner dimension (K).")
    parser.add_argument("--N", type=int, required=True, help="Columns of B / O (N).")
    parser.add_argument("--seed", type=int, default=None, help="Random seed (optional).")
    parser.add_argument("--out", type=str, default="./data/.",
                        help="Output directory for hex files (default: current dir).")
    parser.add_argument("--tokens-per-line", type=int, default=1,
                        help="How many hex values per line (default: 1).")
    parser.add_argument("--dump_txt", type=bool, default=False, help="Set true if you want to dump matrix text.")
    parser.add_argument("--A-file", type=str, default="A.hex", help="Filename for A matrix hex.")
    parser.add_argument("--B-file", type=str, default="B.hex", help="Filename for B matrix hex.")
    parser.add_argument("--O-file", type=str, default="O.hex", help="Filename for output hex.")

    args = parser.parse_args()

    A, B, O = generate_gemm_hex(
        M=args.M,
        K=args.K,
        N=args.N,
        seed=args.seed,
        out_dir=args.out,
        a_filename=args.A_file,
        b_filename=args.B_file,
        o_filename=args.O_file,
        tokens_per_line=args.tokens_per_line,
        dump_txt=args.dump_txt,
    )

