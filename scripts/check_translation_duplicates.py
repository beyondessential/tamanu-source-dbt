import pandas as pd
import sys
import os

def check_translation_duplicates(file_path):
    """Check for duplicates in translation file"""
    if not os.path.exists(file_path):
        print(f"Translation file not found: {file_path}")
        return False
    
    # Read the translation file
    df = pd.read_csv(file_path)
    
    # Check for duplicates in stringId
    stringid_duplicates = df[df.duplicated('stringId', keep=False)]
    
    print(f'Total rows: {len(df)}')
    print(f'Unique stringIds: {df["stringId"].nunique()}')
    print(f'Duplicate stringIds: {len(stringid_duplicates)}')
    
    has_duplicates = False
    
    if len(stringid_duplicates) > 0:
        print('\nDuplicate stringIds found:')
        print(stringid_duplicates.to_string(index=False))
        has_duplicates = True
    else:
        print('✅ No duplicate stringIds found')
    
    # Also check for duplicate default values (which might be acceptable)
    default_duplicates = df[df.duplicated('default', keep=False)]
    print(f'\nDuplicate default values: {len(default_duplicates)}')
    
    if len(default_duplicates) > 0:
        print('\nDuplicate default values found (may be acceptable):')
        print(default_duplicates.to_string(index=False))
    else:
        print('✅ No duplicate default values found')
    
    return not has_duplicates

if __name__ == "__main__":
    # Default to the current version's translation file
    file_path = "compiled/v2.33.1/report_translations_v2.33.1.csv"
    
    if len(sys.argv) > 1:
        file_path = sys.argv[1]
    
    success = check_translation_duplicates(file_path)
    sys.exit(0 if success else 1)
