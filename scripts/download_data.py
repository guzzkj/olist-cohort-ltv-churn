"""Download the Olist dataset from Kaggle into data/raw.

Usage:
    python scripts/download_data.py
"""
import io
import urllib.request
import zipfile
from pathlib import Path

URL = "https://www.kaggle.com/api/v1/datasets/download/olistbr/brazilian-ecommerce"
RAW_DIR = Path(__file__).resolve().parents[1] / "data" / "raw"
NEEDED = {
    "olist_orders_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_customers_dataset.csv",
}


def main() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(URL) as response:
        archive = zipfile.ZipFile(io.BytesIO(response.read()))
    for name in NEEDED:
        archive.extract(name, RAW_DIR)
        print(f"saved {RAW_DIR / name}")


if __name__ == "__main__":
    main()
