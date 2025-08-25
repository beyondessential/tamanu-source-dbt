import great_expectations as gx
import glob
import os
from pathlib import Path


def get_context(root_dir):
    """Get GX context with fallback to ephemeral"""
    try:
        context = gx.get_context(mode="file", project_root_dir=root_dir)
        print("✓ Using file-based context")
        return context
    except Exception as e:
        print(f"⚠ File context failed ({e}), using ephemeral")
        return gx.get_context(mode="ephemeral")


def get_or_create_datasource(context, name="tamanu"):
    """Get existing or create new PostgreSQL datasource"""

    # Use variable substitution syntax for Great Expectations
    env_var_name = name.upper() + "_DB_CONNECTION_STRING"
    connection_string = f"${{{env_var_name}}}"
    
    # Check if the environment variable exists
    if not os.getenv(env_var_name):
        raise ValueError(
            f"Environment variable {env_var_name} is not set or is empty"
        )

    try:
        ds = context.data_sources.get(name)
        print(f"✓ Using existing datasource: {name}")
        return ds
    except Exception as e:
        print(f"⚠ Could not get existing datasource ({e}), creating new one")
        try:
            ds = context.data_sources.add_postgres(
                name=name, connection_string=connection_string
            )
            print(f"✓ Created datasource: {name}")
            return ds
        except Exception as create_error:
            print(f"✗ Failed to create datasource {name}: {create_error}")
            raise


def get_dataset_files(root_dir):
    """Get .sql files from models/datasets/"""
    datasets_path = root_dir / "models" / "datasets"
    return glob.glob(str(datasets_path / "*.sql")), datasets_path


def create_data_assets_and_batches(data_source, sql_files):
    """Create data assets and batch definitions"""
    counts = {
        "added_assets": 0,
        "skipped_assets": 0,
        "added_batches": 0,
        "skipped_batches": 0,
    }

    for sql_file in sql_files:
        table_name = Path(sql_file).stem

        # Get or create data asset
        try:
            asset = data_source.get_asset(table_name)
            counts["skipped_assets"] += 1
        except Exception as e:
            try:
                asset = data_source.add_table_asset(
                    name=table_name, table_name=table_name, schema_name="reporting"
                )
                print(f"✓ Added data asset: {table_name}")
                counts["added_assets"] += 1
            except Exception as e:
                print(f"✗ Failed to add data asset {table_name}: {e}")
                continue

        # Get or create batch definition
        batch_name = f"{table_name}_batch_definition"
        try:
            asset.get_batch_definition(batch_name)
            counts["skipped_batches"] += 1
        except Exception as e:
            try:
                asset.add_batch_definition_whole_table(name=batch_name)
                counts["added_batches"] += 1
            except Exception as e:
                print(f"✗ Failed to add batch definition {batch_name}: {e}")

    return (
        counts["added_assets"],
        counts["skipped_assets"],
        counts["added_batches"],
        counts["skipped_batches"],
    )


def print_summary(
    added_assets,
    skipped_assets,
    added_batches,
    skipped_batches,
    added_suites,
    skipped_suites,
    failed_suites,
    total_files,
):
    """Print setup summary"""
    print(f"\n{'='*50}")
    print("SUMMARY")
    print(f"{'='*50}")
    for label, added, skipped in [
        ("Data Assets", added_assets, skipped_assets),
        ("Batch Definitions", added_batches, skipped_batches),
        ("Expectation Suites", added_suites, skipped_suites),
    ]:
        print(
            f"{label}: ✓ {added} added, ⚪ {skipped} skipped"
            + (f", ✗ {failed_suites} failed" if label == "Expectation Suites" else "")
        )

    print(f"\nTotal files processed: {total_files}")

    if any([added_assets, added_batches, added_suites]):
        print("🎉 Setup completed successfully!")
    else:
        print("✓ All components exist - no changes needed")
