import argparse
from pathlib import Path

from utils.dbt_utils import get_deployment_name, get_deployment_version, get_dbt_project_config
from utils.file_utils import read_file, write_file
from utils.system_utils import cprint

BASE_DIR = Path.cwd()
VERSION = get_deployment_version()
DEPLOYMENT = get_deployment_name()

COMPILED_DIR = BASE_DIR / "compiled"
VERSION_DIR = COMPILED_DIR / f"v{VERSION}"
MANIFEST_FILE = COMPILED_DIR / "manifest.json"


def get_supported_languages():
    """Get the list of supported languages from dbt_project.yml"""
    config = get_dbt_project_config()
    return config.get("vars", {}).get("supported_languages", ["default"])


def restore_original_language():
    """Restore the original language setting to first supported language"""
    import yaml
    import os
    
    supported_languages = get_supported_languages()
    first_language = supported_languages[0] if supported_languages else "default"
    
    config_path = os.path.join(BASE_DIR, "dbt_project.yml")
    
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
    
    config['vars']['language'] = first_language
    
    with open(config_path, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)
    
    cprint(f"Restored dbt_project.yml language to: {first_language}", "info")


def compile_manifest_for_language(language=None):
    """Compile manifest for a specific language"""
    lang_suffix = f"-{language}" if language and language != "default" else ""
    
    version = ".".join(VERSION.split(".")[:2])
    schema = f"reporting-schema-v{VERSION}-{DEPLOYMENT}{lang_suffix}.sql"
    
    # Look for language-specific files or default files
    if language and language != "default":
        reports = [f"./{VERSION}/{file.name}" for file in VERSION_DIR.glob(f"*-{language}.json")]
    else:
        # For default language, look for files without language suffix
        all_files = list(VERSION_DIR.glob("*.json"))
        reports = [f"./{VERSION}/{file.name}" for file in all_files 
                  if not any(file.name.endswith(f"-{lang}.json") 
                           for lang in get_supported_languages() if lang != "default")]

    entry_key = f"~{version}.0{lang_suffix}"
    entry = {
        "tamanu": entry_key,
        "schema": schema,
        "reports": sorted(reports),
        "language": language or "default"
    }

    if MANIFEST_FILE.exists():
        manifest = read_file(MANIFEST_FILE, "json")
    else:
        manifest = {"deploymentName": DEPLOYMENT, "versions": []}

    # Remove existing entry for this version and language
    manifest["versions"] = [
        versions
        for versions in manifest["versions"]
        if versions["tamanu"] != entry_key
    ]
    manifest["versions"].append(entry)
    manifest["versions"].sort(key=lambda x: x["tamanu"], reverse=True)

    write_file(MANIFEST_FILE, manifest, "json")
    cprint(
        f"Manifest updated for {language or 'default'}: {len(reports)} reports added for version {version}",
        "success",
    )


def main():
    parser = argparse.ArgumentParser(description="Compile Tamanu reporting manifest")
    parser.add_argument(
        "--language", 
        type=str, 
        help="Compile manifest for specific language (e.g., 'en', 'fr', 'es', 'to'). Use 'all' to compile for all supported languages."
    )
    parser.add_argument(
        "--list-languages", 
        action="store_true", 
        help="List all supported languages and exit"
    )
    
    args = parser.parse_args()
    
    # Handle list languages option
    if args.list_languages:
        supported_languages = get_supported_languages()
        cprint(f"Supported languages: {', '.join(supported_languages)}", "info")
        return

    cprint(f"Compiling manifest for deployment: {DEPLOYMENT} - {VERSION}", "info")

    if not COMPILED_DIR.exists() or not VERSION_DIR.exists():
        cprint(
            "Please run build_reporting_assets.py first to generate compiled assets",
            "error",
        )
        return

    try:
        if args.language:
            if args.language.lower() == "all":
                # Compile for all supported languages
                supported_languages = get_supported_languages()
                cprint(f"Compiling manifest for all supported languages: {', '.join(supported_languages)}", "info")
                
                for language in supported_languages:
                    compile_manifest_for_language(language)
                
                cprint(f"Multi-language manifest compilation completed for {len(supported_languages)} languages!", "success")
                
            else:
                # Compile for specific language
                supported_languages = get_supported_languages()
                if args.language not in supported_languages:
                    cprint(f"Error: Language '{args.language}' not in supported languages: {', '.join(supported_languages)}", "error")
                    return
                
                compile_manifest_for_language(args.language)
                cprint(f"Manifest compilation completed for language: {args.language}", "success")
        else:
            # Default behavior - compile for default language only
            compile_manifest_for_language()
            
    except Exception as e:
        cprint(f"Error during manifest compilation: {e}", "error")
        raise
    finally:
        # Always restore the original language setting
        restore_original_language()


if __name__ == "__main__":
    main()
