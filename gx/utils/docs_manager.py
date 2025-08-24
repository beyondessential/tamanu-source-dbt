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
