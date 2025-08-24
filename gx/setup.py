from pathlib import Path
import argparse
from utils.asset_manager import *
from utils.batch_refresher import *
from utils.suite_manager import *
from utils.validation_manager import *
from utils.docs_manager import *


def main():
    """Setup GX assets, suites, and validation definitions"""
    parser = argparse.ArgumentParser(description="GX setup - create assets, suites, and validation definitions")
    parser.add_argument("--refresh-batches", action="store_true", help="Refresh batch definitions")
    parser.add_argument("--datasource", default="tamanu", help="Datasource name (default: tamanu)")
    args = parser.parse_args()

    root_dir = Path(__file__).parent.parent
    context = get_context(root_dir)
    data_source = get_or_create_datasource(context, name=args.datasource)
    sql_files, datasets_path = get_dataset_files(root_dir)

    print(f"Processing {len(sql_files)} dataset files from {datasets_path}")

    # Create assets and batches
    added_assets, skipped_assets, added_batches, skipped_batches = create_data_assets_and_batches(data_source, sql_files)

    # Refresh batches if requested
    refreshed_batches = 0
    if args.refresh_batches:
        table_names = [Path(f).stem for f in sql_files]
        refreshed_batches, _, _ = refresh_batch_definitions(data_source, table_names, force_refresh=True)
        print(f"Refreshed {refreshed_batches} batch definitions")

    # Create expectation suites and validation definitions
    added_suites, skipped_suites, failed_suites = create_expectation_suites_from_files(context, root_dir)
    added_validations, skipped_validations, failed_validations, checkpoint_success = create_validation_definitions_and_checkpoint(context, data_source, root_dir)

    # Summary
    print(f"\n{'='*50}")
    print("SETUP SUMMARY")
    print(f"{'='*50}")
    for label, added, skipped in [
        ("Data Assets", added_assets, skipped_assets),
        ("Batch Definitions", added_batches, skipped_batches),
        ("Expectation Suites", added_suites, failed_suites),
        ("Validation Definitions", added_validations, failed_validations)
    ]:
        print(f"{label}: ✓ {added} {'added' if 'Assets' in label or 'Batch' in label else 'reloaded'}, {'⚪' if 'Assets' in label or 'Batch' in label else '✗'} {skipped} {'skipped' if 'Assets' in label or 'Batch' in label else 'failed'}")
    
    if refreshed_batches > 0:
        print(f"Batch Refreshes: 🔄 {refreshed_batches} refreshed")
    
    print(f"Checkpoint: {'✅ Created' if checkpoint_success else '❌ Failed'}")

    build_data_docs(context)
    
    if checkpoint_success:
        print("\n🎉 Setup completed successfully!")
        print("💡 Run 'python gx/validate.py' to execute validations")
    else:
        print("\n⚠ Setup completed with issues")


if __name__ == "__main__":
    main()
