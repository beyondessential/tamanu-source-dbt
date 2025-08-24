from pathlib import Path
import argparse
import json
import os
from utils.validation_manager import *
from utils.result_extractor import *
from utils.docs_manager import *
from utils.asset_manager import get_context


def setup_environment_variables(datasource_name="tamanu"):
    """Set up environment variables for datasource connection"""
    # Build connection string from individual environment variables
    connection_string = "postgresql+psycopg2://" + \
        f"{os.environ.get(datasource_name.upper() + '_DB_USER')}:" + \
        f"{os.environ.get(datasource_name.upper() + '_DB_PASSWORD')}@" + \
        f"{os.environ.get(datasource_name.upper() + '_DB_URL')}:" + \
        f"{os.environ.get(datasource_name.upper() + '_DB_PORT')}/" + \
        f"{os.environ.get(datasource_name.upper() + '_DB_DATABASE')}"

    # Set the connection string environment variable that GX config expects
    connection_string_env_var = f"{datasource_name.upper()}_DB_CONNECTION_STRING"
    os.environ[connection_string_env_var] = connection_string
    print(f"✓ Set {connection_string_env_var} environment variable")


def main():
    """Run GX validations and generate reports"""
    parser = argparse.ArgumentParser(description="GX validation - run validations and generate reports")
    parser.add_argument("--checkpoint", default="tamanu_data_quality_checkpoint", help="Checkpoint name")
    parser.add_argument("--no-docs", action="store_true", help="Skip building data docs")
    parser.add_argument("--no-browser", action="store_true", help="Don't auto-open browser")
    parser.add_argument("--output", default="complete_validation_results.json", help="Output file")
    parser.add_argument("--datasource", default="tamanu", help="Datasource name")
    args = parser.parse_args()

    root_dir = Path(__file__).parent.parent
    
    # Set up environment variables
    setup_environment_variables(args.datasource)
    
    context = get_context(root_dir)

    checkpoint_result = run_checkpoint(context, args.checkpoint)
    if not checkpoint_result:
        print("❌ Checkpoint execution failed")
        return 1

    # Save results to file
    output_file = root_dir / "gx" / args.output
    try:
        # Try to convert checkpoint result to a serializable format
        result_dict = {
            "success": checkpoint_result.success,
            "run_id": str(checkpoint_result.run_id) if hasattr(checkpoint_result, 'run_id') else None,
            "run_time": checkpoint_result.run_time.isoformat() if hasattr(checkpoint_result, 'run_time') and checkpoint_result.run_time else None,
            "checkpoint_config": checkpoint_result.checkpoint_config.to_json_dict() if hasattr(checkpoint_result.checkpoint_config, 'to_json_dict') else str(checkpoint_result.checkpoint_config) if hasattr(checkpoint_result, 'checkpoint_config') else None,
            "run_results": {}
        }
        
        # Extract run results
        for validation_result_id, validation_result in checkpoint_result.run_results.items():
            result_dict["run_results"][str(validation_result_id)] = {
                "success": validation_result.success,
                "statistics": validation_result.statistics if hasattr(validation_result, 'statistics') else {},
                "meta": validation_result.meta if hasattr(validation_result, 'meta') else {}
            }
        
        with open(output_file, "w") as f:
            json.dump(result_dict, f, indent=2)
            print(f"💾 Results saved to: {output_file}")
    except Exception as e:
        print(f"⚠ Could not save results to JSON: {e}")
        # Save a simple text summary instead
        text_output_file = output_file.with_suffix('.txt')
        with open(text_output_file, "w") as f:
            f.write(f"Checkpoint Results Summary\n")
            f.write(f"========================\n")
            f.write(f"Success: {checkpoint_result.success}\n")
            f.write(f"Run ID: {getattr(checkpoint_result, 'run_id', 'N/A')}\n")
            f.write(f"Run Time: {getattr(checkpoint_result, 'run_time', 'N/A')}\n")
            f.write(f"\nValidation Results:\n")
            for validation_result_id, validation_result in checkpoint_result.run_results.items():
                f.write(f"  {validation_result_id}: {'PASSED' if validation_result.success else 'FAILED'}\n")
        print(f"💾 Results summary saved to: {text_output_file}")
    
    # Extract and display results
    validation_results = extract_validation_results(checkpoint_result)
    print_validation_summary(validation_results)
    
    # Build docs if requested
    if not args.no_docs:
        build_data_docs(context)
        if not args.no_browser:
            open_data_docs(context, auto_open=True)

    # Final summary
    success_rate = validation_results.get("statistics", {}).get("success_rate", 0)
    overall_success = checkpoint_result.success
    
    print(f"\n{'='*50}")
    print("VALIDATION SUMMARY")
    print(f"{'='*50}")
    print(f"Checkpoint: {'✅ PASSED' if overall_success else '❌ FAILED'}")
    print(f"Success Rate: {success_rate:.1f}%")
    if not args.no_docs:
        print("📊 Data docs updated")
    
    return 0 if overall_success else 1


if __name__ == "__main__":
    exit(main())
