import great_expectations as gx
import glob
import importlib.util
from pathlib import Path


def create_validation_definition(context, data_source, asset_name, suite_name):
    """Create validation definition for asset and suite"""
    try:
        data_asset = data_source.get_asset(asset_name)
        batch_def = data_asset.get_batch_definition(f"{asset_name}_batch_definition")
        suite = context.suites.get(suite_name)
        validation_name = f"{asset_name}_validation"
        
        try:
            context.validation_definitions.delete(validation_name)
        except Exception:
            pass
            
        context.validation_definitions.add(
            gx.ValidationDefinition(name=validation_name, data=batch_def, suite=suite)
        )
        print(f"  ✓ Reloaded validation definition: {validation_name}")
        return True, "reloaded"
    except Exception as e:
        print(f"  ✗ Failed to create validation definition for {asset_name}: {e}")
        return False, "failed"


def create_checkpoint(context, validation_definitions):
    """Create checkpoint with validation definitions"""
    name = "tamanu_data_quality_checkpoint"
    try:
        # Delete existing checkpoint first
        try:
            context.checkpoints.delete(name)
            print(f"✓ Deleted existing checkpoint: {name}")
        except Exception:
            pass  # Checkpoint doesn't exist, that's fine
            
        # Create new checkpoint
        context.checkpoints.add(
            gx.Checkpoint(name=name, validation_definitions=validation_definitions, result_format="SUMMARY")
        )
        print(f"✓ Reloaded checkpoint: {name} with {len(validation_definitions)} validation definitions")
        return True, "reloaded"
    except Exception as e:
        print(f"✗ Failed to create checkpoint: {e}")
        return False, "failed"


def create_validation_definitions_and_checkpoint(context, data_source, root_dir):
    """Create validation definitions from Python expectation suites"""
    expectations_dir = root_dir / "gx" / "expectations"
    python_files = glob.glob(str(expectations_dir / "*_expectations.py"))
    
    if not python_files:
        print("⚠ No Python expectation files found")
        return 0, 0, 0, False
        
    print(f"\nFound {len(python_files)} Python expectation file(s)")
    
    added, failed = 0, 0
    validation_definitions = []
    
    for python_file in python_files:
        suite_name = Path(python_file).stem
        asset_name = suite_name.replace("_expectations", "")
        print(f"\nProcessing Python suite: {suite_name} -> asset: {asset_name}")
        
        try:
            spec = importlib.util.spec_from_file_location("expectation_module", python_file)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            
            if hasattr(module, 'main'):
                module.main()  # Create suite
                success, _ = create_validation_definition(context, data_source, asset_name, suite_name)
                
                if success:
                    added += 1
                    try:
                        validation_def = context.validation_definitions.get(f"{asset_name}_validation")
                        validation_definitions.append(validation_def)
                    except Exception as e:
                        print(f"  ⚠ Could not add validation definition: {e}")
                else:
                    failed += 1
            else:
                print(f"  ✗ No 'main' function found")
                failed += 1
        except Exception as e:
            print(f"  ✗ Failed to process {Path(python_file).name}: {e}")
            failed += 1
    
    checkpoint_success = False
    if validation_definitions:
        checkpoint_success, _ = create_checkpoint(context, validation_definitions)
    
    return added, 0, failed, checkpoint_success


def run_checkpoint(context, checkpoint_name="tamanu_data_quality_checkpoint"):
    """Run checkpoint and return results"""
    try:
        checkpoint = context.checkpoints.get(checkpoint_name)
        print(f"\n🚀 Running checkpoint: {checkpoint_name}")
        result = checkpoint.run()
        print(f"✓ Checkpoint run completed. Success: {result.success}")
        return result
    except Exception as e:
        print(f"✗ Failed to run checkpoint: {e}")
        return False
