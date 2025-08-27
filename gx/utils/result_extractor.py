"""Great Expectations Result Extractor"""

import great_expectations as gx
import json
from typing import Dict, Any
from datetime import datetime


def extract_validation_results(checkpoint_result) -> Dict[str, Any]:
    """Extract validation results from checkpoint result"""
    try:
        if not checkpoint_result:
            return {}

        summary = {
            "run_id": str(checkpoint_result.run_id),
            "run_time": datetime.now().isoformat(),
            "success": checkpoint_result.success,
            "validation_results": [],
            "statistics": {"total_expectations": 0, "successful_expectations": 0, "failed_expectations": 0, "success_rate": 0.0},
            "failed_expectations": [],
        }

        for identifier, vr in checkpoint_result.run_results.items():
            validation_info = {
                "validation_result_identifier": str(identifier),
                "success": vr.success,
                "statistics": getattr(vr, "statistics", {}),
                "meta": getattr(vr, "meta", {}),
                "expectations": [],
            }

            if hasattr(vr, "statistics"):
                summary["statistics"]["total_expectations"] += vr.statistics.get("evaluated_expectations", 0)
                summary["statistics"]["successful_expectations"] += vr.statistics.get("successful_expectations", 0)

            if hasattr(vr, "results"):
                for exp_result in vr.results:
                    exp_info = {
                        "expectation_type": exp_result.expectation_config.type,
                        "success": exp_result.success,
                        "kwargs": exp_result.expectation_config.kwargs,
                        "meta": getattr(exp_result.expectation_config, "meta", {}),
                        "result": {
                            attr: getattr(exp_result.result, attr, None)
                            for attr in ["observed_value", "element_count", "missing_count", "missing_percent", 
                                       "unexpected_count", "unexpected_percent", "partial_unexpected_list"]
                        } if hasattr(exp_result, "result") else {},
                    }
                    
                    validation_info["expectations"].append(exp_info)
                    
                    if not exp_result.success:
                        summary["failed_expectations"].append({
                            "expectation_type": exp_result.expectation_config.type,
                            "kwargs": exp_result.expectation_config.kwargs,
                            "meta": getattr(exp_result.expectation_config, "meta", {}),
                            "result": exp_info["result"],
                        })

            summary["validation_results"].append(validation_info)

        total = summary["statistics"]["total_expectations"]
        successful = summary["statistics"]["successful_expectations"]
        summary["statistics"]["failed_expectations"] = total - successful
        summary["statistics"]["success_rate"] = (successful / total * 100) if total > 0 else 0.0

        return summary
    except Exception as e:
        return {"error": str(e), "success": False, "run_time": datetime.now().isoformat()}


def print_validation_summary(validation_results: Dict[str, Any]) -> None:
    """Print formatted validation results summary"""
    if "error" in validation_results:
        print(f"❌ Error extracting validation results: {validation_results['error']}")
        return

    stats = validation_results["statistics"]
    print(f"\n📊 Validation Results Summary:")
    print(f"  Run ID: {validation_results['run_id']}")
    print(f"  Run Time: {validation_results['run_time']}")
    print(f"  Overall Success: {'✅' if validation_results['success'] else '❌'}")
    print(f"  Total Expectations: {stats['total_expectations']}")
    print(f"  Successful: {stats['successful_expectations']}")
    print(f"  Failed: {stats['failed_expectations']}")
    print(f"  Success Rate: {stats['success_rate']:.1f}%")

    if validation_results["failed_expectations"]:
        print(f"\n❌ Failed Expectations ({len(validation_results['failed_expectations'])}):")
        for i, failure in enumerate(validation_results["failed_expectations"][:10], 1):
            print(f"  {i}. {failure['expectation_type']}")
            if "column" in failure["kwargs"]:
                print(f"     Column: {failure['kwargs']['column']}")
            if "description" in failure.get("meta", {}):
                print(f"     Description: {failure['meta']['description']}")
            if failure["result"].get("observed_value") is not None:
                print(f"     Observed: {failure['result']['observed_value']}")
            if failure["result"].get("unexpected_count"):
                print(f"     Unexpected Count: {failure['result']['unexpected_count']}")

        if len(validation_results["failed_expectations"]) > 10:
            print(f"     ... and {len(validation_results['failed_expectations']) - 10} more")


def save_validation_results(validation_results: Dict[str, Any], output_file: str = "validation_results.json") -> bool:
    """Save validation results to JSON file"""
    try:
        with open(output_file, "w") as f:
            json.dump(validation_results, f, indent=2, default=str)
        print(f"💾 Validation results saved to: {output_file}")
        return True
    except Exception as e:
        print(f"❌ Failed to save validation results: {e}")
        return False
