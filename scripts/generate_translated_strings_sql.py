#!/usr/bin/env python3
"""
Keep this script until default translations are part of the automated import process.

Script to generate translated_strings_default.sql from report_translation_strings.csv
This creates a SQL view that can be used as a dbt model.
"""

import csv
import os

def generate_sql_view():
    """Generate the SQL view content from the CSV file."""
    csv_path = 'report_translations.csv'
    sql_path = 'models/translated_strings_default.sql'
    
    if not os.path.exists(csv_path):
        print(f"Error: {csv_path} not found")
        return
    
    sql_content = []
    sql_content.append("select")
    sql_content.append("    string_id,")
    sql_content.append("    'default' as language,")
    sql_content.append("    text")
    sql_content.append("from (")
    sql_content.append("    values")
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        next(reader)  # Skip header
        
        rows = list(reader)
        for i, row in enumerate(rows):
            if len(row) >= 2:
                string_id = row[0]
                text = row[1].replace("'", "''")  # Escape single quotes
                
                if i == len(rows) - 1:  # Last row
                    sql_content.append(f"    ('{string_id}', '{text}')")
                else:
                    sql_content.append(f"    ('{string_id}', '{text}'),")
    
    sql_content.append(") as t(string_id, text)")
    
    # Write the SQL to file
    with open(sql_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(sql_content))
    
    print(f"Generated SQL view at {sql_path}")
    print(f"Processed {len(rows)} translation strings")

if __name__ == '__main__':
    generate_sql_view()
