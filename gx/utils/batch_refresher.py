import great_expectations as gx


def refresh_batch_definitions(data_source, table_names, force_refresh=False):
    """Refresh batch definitions to pick up schema changes"""
    counts = {"refreshed": 0, "skipped": 0, "failed": 0}
    
    for table_name in table_names:
        try:
            asset = data_source.get_asset(table_name)
            batch_name = f"{table_name}_batch_definition"
            
            print(f"\nProcessing: {table_name}")
            
            try:
                asset.get_batch_definition(batch_name)
                if force_refresh:
                    print(f"  🔄 Force refreshing: {batch_name}")
                    asset.delete_batch_definition(batch_name)
                    asset.add_batch_definition_whole_table(name=batch_name)
                    print(f"  ✓ Refreshed: {batch_name}")
                    counts["refreshed"] += 1
                else:
                    print(f"  ⚪ Exists, skipping (use force_refresh=True)")
                    counts["skipped"] += 1
            except:
                print(f"  ✓ Creating: {batch_name}")
                asset.add_batch_definition_whole_table(name=batch_name)
                counts["refreshed"] += 1
                
        except Exception as e:
            print(f"  ✗ Failed for {table_name}: {e}")
            counts["failed"] += 1
    
    return counts["refreshed"], counts["skipped"], counts["failed"]


def refresh_specific_batch_definition(data_source, table_name, batch_name=None):
    """Refresh specific batch definition"""
    batch_name = batch_name or f"{table_name}_batch_definition"
    
    try:
        asset = data_source.get_asset(table_name)
        print(f"🔄 Refreshing: {batch_name}")
        
        try:
            asset.get_batch_definition(batch_name)
            asset.delete_batch_definition(batch_name)
            print("  ✓ Deleted existing")
        except:
            print("  ℹ No existing definition")
        
        asset.add_batch_definition_whole_table(name=batch_name)
        print("  ✓ Created with current schema")
        return True
        
    except Exception as e:
        print(f"  ✗ Failed: {e}")
        return False


def refresh_partitioned_batch_definition(data_source, table_name, column_name, partition_method="partition_on_year_and_month_and_day"):
    """Refresh partitioned batch definition"""
    batch_name = f"{table_name}_yesterday_batch_definition"
    
    try:
        asset = data_source.get_asset(table_name)
        print(f"🔄 Refreshing partitioned: {batch_name}")
        
        try:
            asset.get_batch_definition(batch_name)
            asset.delete_batch_definition(batch_name)
            print("  ✓ Deleted existing partitioned")
        except:
            print("  ℹ No existing partitioned definition")
        
        if partition_method == "partition_on_year_and_month_and_day":
            asset.add_batch_definition_monthly(name=batch_name, column=column_name)
            print("  ✓ Created partitioned with current schema")
            return True
        else:
            print(f"  ⚠ Partition method {partition_method} not implemented")
            return False
            
    except Exception as e:
        print(f"  ✗ Failed: {e}")
        return False


def list_batch_definitions(data_source, table_name):
    """List batch definitions for table"""
    try:
        asset = data_source.get_asset(table_name)
        batch_defs = asset.batch_definitions
        
        print(f"\nBatch definitions for {table_name}:")
        for name, batch_def in batch_defs.items():
            partitioner = f" (Partitioner: {batch_def.partitioner})" if hasattr(batch_def, 'partitioner') and batch_def.partitioner else ""
            print(f"  - {name}{partitioner}")
        
        return list(batch_defs.keys())
        
    except Exception as e:
        print(f"✗ Failed to list for {table_name}: {e}")
        return []
