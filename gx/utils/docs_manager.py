import great_expectations as gx
import webbrowser


def build_data_docs(context):
    """Build GX Data Docs"""
    try:
        print("🔨 Building Data Docs...")
        context.build_data_docs()
        print("✓ Data Docs built successfully")
        return True
    except Exception as e:
        print(f"✗ Failed to build Data Docs: {e}")
        return False


def open_data_docs(context, auto_open=True):
    """Open Data Docs in browser"""
    try:
        sites = context.get_docs_sites_urls()
        if not sites:
            print("⚠ No Data Docs sites found")
            return False
        
        site_url = sites[0].get('site_url', '')
        print(f"📊 Data Docs: {site_url}")
        
        if auto_open and site_url:
            try:
                webbrowser.open(site_url)
                print("🌐 Opened in browser")
            except Exception as e:
                print(f"⚠ Auto-open failed: {e}")
                print(f"💡 Manually open: {site_url}")
        
        return True
    except Exception as e:
        print(f"✗ Failed to get Data Docs URLs: {e}")
        return False


def setup_data_docs_config(context):
    """Check Data Docs configuration"""
    try:
        config = context.get_config()
        if 'data_docs_sites' not in config or not config['data_docs_sites']:
            print("⚠ No Data Docs sites configured")
            print("💡 Consider adding data_docs_sites to great_expectations.yml")
        return True
    except Exception as e:
        print(f"✗ Failed to check Data Docs config: {e}")
        return False


def generate_validation_report(context, checkpoint_name="tamanu_data_quality_checkpoint", open_browser=True):
    """Run validations and generate report"""
    try:
        print("🚀 Running validations...")
        
        checkpoint = context.checkpoints.get(checkpoint_name)
        result = checkpoint.run()
        
        if build_data_docs(context):
            open_data_docs(context, auto_open=open_browser)
        
        # Calculate summary
        success_count = total_count = 0
        failed_validations = []
        
        for validation_result in result.run_results.values():
            if hasattr(validation_result, 'validation_result'):
                vr = validation_result.validation_result
                if hasattr(vr, 'statistics'):
                    total_count += vr.statistics.get('evaluated_expectations', 0)
                    success_count += vr.statistics.get('successful_expectations', 0)
                
                if hasattr(vr, 'results'):
                    failed_validations.extend([
                        {
                            'expectation_type': getattr(exp_result.expectation_config, 'type', 'unknown'),
                            'kwargs': exp_result.expectation_config.kwargs
                        }
                        for exp_result in vr.results if not exp_result.success
                    ])
        
        success_rate = (success_count / total_count * 100) if total_count > 0 else 0
        
        print(f"\n📊 Summary: {success_count}/{total_count} passed ({success_rate:.1f}%)")
        
        if failed_validations:
            print("❌ Failed Expectations:")
            for i, failure in enumerate(failed_validations[:5], 1):
                exp_type = failure['expectation_type']
                kwargs = failure['kwargs']
                column = f" (Column: {kwargs['column']})" if 'column' in kwargs else ""
                print(f"  {i}. {exp_type}{column}")
            
            if len(failed_validations) > 5:
                print(f"     ... and {len(failed_validations) - 5} more")
        
        return result.success
    except Exception as e:
        print(f"✗ Failed to generate report: {e}")
        return False
