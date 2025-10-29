import sys
from pathlib import Path

import pandas as pd
from utils.system_utils import cprint


def main():
    if len(sys.argv) != 2:
        cprint("Usage: python convert_translations_to_excel_file.py <csv_file>")
        sys.exit(1)

    csv_translations_file_path = Path(sys.argv[1])
    if not csv_translations_file_path.exists():
        cprint(f"Error: File not found: {csv_translations_file_path}")
        sys.exit(1)

    excel_translations_file_path = csv_translations_file_path.with_suffix(".xlsx")
    try:
        df = pd.read_csv(csv_translations_file_path)
        df.to_excel(excel_translations_file_path, index=False)
        cprint(
            f"Converted: {csv_translations_file_path} → {excel_translations_file_path}"
        )
    except Exception as e:
        cprint(f"Conversion failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
