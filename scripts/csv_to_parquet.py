#!/usr/bin/env python3
"""Convert CSV files to Parquet format."""

import sys
from pathlib import Path

import pandas as pd


def csv_to_parquet(csv_path: str, parquet_path: str | None = None) -> Path:
    """Convert a CSV file to Parquet format.

    Args:
        csv_path: Path to the input CSV file.
        parquet_path: Path for the output Parquet file. If not provided,
                      uses the same name as the CSV with .parquet extension.

    Returns:
        Path to the created Parquet file.
    """
    csv_file = Path(csv_path)
    if not csv_file.exists():
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    if parquet_path is None:
        parquet_file = csv_file.with_suffix(".parquet")
    else:
        parquet_file = Path(parquet_path)

    # Ensure output directory exists
    parquet_file.parent.mkdir(parents=True, exist_ok=True)

    # Read CSV and write to Parquet
    df = pd.read_csv(csv_file)
    df.to_parquet(parquet_file, index=False, engine="pyarrow")

    print(f"Converted {csv_file} -> {parquet_file}")
    print(f"  Rows: {len(df)}, Columns: {len(df.columns)}")
    print(f"  Columns: {', '.join(df.columns)}")

    return parquet_file


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: csv_to_parquet.py <csv_file> [parquet_file]")
        sys.exit(1)

    csv_path = sys.argv[1]
    parquet_path = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        csv_to_parquet(csv_path, parquet_path)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
