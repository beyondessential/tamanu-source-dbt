from pathlib import Path
import argparse
import json
from utils.validation_manager import *
from utils.result_extractor import *
from utils.docs_manager import *
from utils.asset_manager import get_context


def save_results(checkpoint_result, output_file):
    """Save checkpoint results to JSON with fallback to text"""
    try:
        result_dict = {
            "run_id": str(checkpoint_result.run_id),
            "success": checkpoint_result.success,
            "run_results": {},
            "checkpoint_config": str(checkpoint_result.checkpoint_config),
        }

        for identifier, validation_result in checkpoint_result.run_results.items():
            result_dict["run_results"][str(identifier)] = {
                "success": validation_result.success,
                "results": [
                    {
                        "success": result.success,
                        "expectation_config": {
                            "type": result.expectation_config.type,
                            "kwargs": result.expectation_config.kwargs,
                            "meta": getattr(result.expectation_config, "meta", {}),
                        },
                        "result": result.result.__dict__ if hasattr(result.result, "__dict__") else str(result.result),
                        "exception_info": {
                            "raised_exception": result.exception_info.get("raised_exception", False) if result.exception_info else False,
                            "exception_message": result.exception_info.get("exception_message") if result.exception_info else None,
                        },
                    }
                    for result in validation_result.results
                ] if hasattr(validation_result, "results") else [],
                "statistics": getattr(validation_result, "statistics", {}),
                "meta": getattr(validation_result, "meta", {}),
            }

        with open(output_file, "w") as f:
            json.dump(result_dict, f, indent=2, default=str)
        print(f"💾 Results saved to: {output_file}")

    except Exception as e:
        print(f"❌ JSON save failed: {e}")
        try:
            txt_file = output_file.with_suffix('.txt')
            with open(txt_file, "w") as f:
                f.write(str(checkpoint_result))
            print(f"💾 Results saved as text to: {txt_file}")
        except Exception as e2:
            print(f"❌ Text save failed: {e2}")


def main():
    """Run GX validations and generate reports"""
    parser = argparse.ArgumentParser(description="GX validation - run validations and generate reports")
    parser.add_argument("--checkpoint", default="tamanu_data_quality_checkpoint", help="Checkpoint name")
    parser.add_argument("--no-docs", action="store_true", help="Skip building data docs")
    parser.add_argument("--no-browser", action="store_true", help="Don't auto-open browser")
    parser.add_argument("--output", default="complete_validation_results.json", help="Output file")
    args = parser.parse_args()

    root_dir = Path(__file__).parent.parent
    context = get_context(root_dir)

    checkpoint_result = run_checkpoint(context, args.checkpoint)
    if not checkpoint_result:
        print("❌ Checkpoint execution failed")
        return 1

    # Extract and display results
    validation_results = extract_validation_results(checkpoint_result)
    print_validation_summary(validation_results)
    
    # Build docs if requested
    if not args.no_docs:
        build_data_docs(context)
        if not args.no_browser:
            open_data_docs(context, auto_open=True)
    
    # Save results
    output_file = root_dir / "gx" / args.output
    save_results(checkpoint_result, output_file)

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
