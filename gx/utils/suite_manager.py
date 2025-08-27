import great_expectations as gx
import glob
import importlib.util
from pathlib import Path


def create_expectation_suites_from_files(context, root_dir):
    """Load expectation suites from Python files"""
    expectations_dir = root_dir / "gx" / "expectations"
    python_files = glob.glob(str(expectations_dir / "*_expectations.py"))

    if not python_files:
        print(f"⚠ No Python expectation files found in {expectations_dir}")
        return 0, 0, 0

    print(f"\nFound {len(python_files)} Python expectation file(s) in {expectations_dir}")
    
    added, failed = 0, 0

    for python_file in python_files:
        file_name = Path(python_file).name
        print(f"\nProcessing Python expectation file: {file_name}")

        try:
            spec = importlib.util.spec_from_file_location("expectation_module", python_file)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            
            if hasattr(module, 'main'):
                suite = module.main()
                print(f"  ✓ Reloaded Python expectation suite: {suite.name} ({len(suite.expectations)} expectations)")
                added += 1
            else:
                print(f"  ✗ No 'main' function found in {python_file}")
                failed += 1
        except Exception as e:
            print(f"  ✗ Failed to process Python expectation file {file_name}: {e}")
            failed += 1

    return added, 0, failed
