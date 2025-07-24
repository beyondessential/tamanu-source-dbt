import os
import re
import csv
from pathlib import Path

def extract_translate_labels_from_file(file_path):
    """Extract all translate_label calls from a SQL file."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern to match translate_label('stringId') or translate_label("stringId")
    pattern = r"translate_label\(['\"]([^'\"]+)['\"]\)"
    matches = re.findall(pattern, content)
    return matches

def load_csv_translations(csv_path):
    """Load all string IDs from the CSV file."""
    string_ids = set()
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Extract the part after 'report.reporting.'
            string_id = row['stringId']
            if string_id.startswith('report.reporting.'):
                string_ids.add(string_id[len('report.reporting.'):])
    return string_ids

def main():
    # Paths
    reports_sql_dir = Path('models/reports/sql')
    csv_file = Path('report_translations.csv')
    
    # Load CSV translations
    csv_translations = load_csv_translations(csv_file)
    print(f"Found {len(csv_translations)} translations in CSV file")
    
    # Extract all translate_label calls from SQL files
    all_translate_labels = set()
    file_translate_labels = {}
    
    for sql_file in reports_sql_dir.glob('*.sql'):
        labels = extract_translate_labels_from_file(sql_file)
        file_translate_labels[sql_file.name] = labels
        all_translate_labels.update(labels)
    
    print(f"Found {len(all_translate_labels)} unique translate_label calls across all SQL files")
    
    # Find missing translations
    missing_translations = all_translate_labels - csv_translations
    
    if missing_translations:
        print(f"\n❌ MISSING TRANSLATIONS ({len(missing_translations)}):")
        print("The following translate_label calls do NOT have corresponding entries in report_translations.csv:")
        
        for missing in sorted(missing_translations):
            print(f"  - {missing}")
            # Show which files use this missing translation
            files_using = [f for f, labels in file_translate_labels.items() if missing in labels]
            print(f"    Used in: {', '.join(files_using)}")
        
        print(f"\nTo fix this, add the following entries to report_translations.csv:")
        for missing in sorted(missing_translations):
            print(f"report.reporting.{missing},<appropriate translation>")
    else:
        print("\n✅ ALL TRANSLATIONS FOUND!")
        print("All translate_label calls have corresponding entries in report_translations.csv")
    
    # Find unused translations (translations in CSV but not used in any SQL file)
    unused_translations = csv_translations - all_translate_labels
    
    if unused_translations:
        print(f"\n⚠️  UNUSED TRANSLATIONS ({len(unused_translations)}):")
        print("The following translations exist in CSV but are not used in any SQL file:")
        for unused in sorted(unused_translations):
            print(f"  - {unused}")
    
    # Summary by file
    print(f"\n📊 SUMMARY BY FILE:")
    for filename, labels in sorted(file_translate_labels.items()):
        missing_in_file = [label for label in labels if label not in csv_translations]
        status = "❌" if missing_in_file else "✅"
        print(f"{status} {filename}: {len(labels)} translate_label calls, {len(missing_in_file)} missing")
        if missing_in_file:
            print(f"    Missing: {', '.join(missing_in_file)}")

if __name__ == "__main__":
    main()
