# AI Rules for tamanu-source-dbt

This directory contains AI rules and guidelines for working with the tamanu-source-dbt project.

## Files

- `tamanu_source_dbt_rules.md` - Comprehensive AI rules for the tamanu-source-dbt project

## Setting up AI Rules for Cline or Cursor

To use these AI rules with Cline or Cursor, you need to create a symbolic link (or hard link on Windows) to make the rules accessible to your AI assistant.

### For Cline

Cline looks for rules in the `.clinerules` directory. Create a symbolic link as follows:

#### On Windows (PowerShell)

```powershell
# Create the .clinerules directory if it doesn't exist
New-Item -ItemType Directory -Path ".clinerules" -Force

# Create a hard link (since symbolic links require admin privileges on Windows)
New-Item -ItemType HardLink -Path ".clinerules\tamanu_source_dbt_rules.md" -Target "ai\tamanu_source_dbt_rules.md"
```

#### On macOS/Linux

```bash
# Create the .clinerules directory if it doesn't exist
mkdir -p .clinerules

# Create a symbolic link
ln -s ../ai/tamanu_source_dbt_rules.md .clinerules/tamanu_source_dbt_rules.md
```

### For Cursor

Cursor looks for rules in the `.cursor/rules` directory. Create a symbolic link as follows:

#### On Windows (PowerShell)

```powershell
# Create the .cursor/rules directory if it doesn't exist
New-Item -ItemType Directory -Path ".cursor\rules" -Force

# Create a hard link (since symbolic links require admin privileges on Windows)
New-Item -ItemType HardLink -Path ".cursor\rules\tamanu_source_dbt_rules.md" -Target "ai\tamanu_source_dbt_rules.md"
```

#### On macOS/Linux

```bash
# Create the .cursor/rules directory if it doesn't exist
mkdir -p .cursor/rules

# Create a symbolic link
ln -s ../../ai/tamanu_source_dbt_rules.md .cursor/rules/tamanu_source_dbt_rules.md
```

## Benefits of Using Links

Using symbolic links (or hard links on Windows) provides several advantages:

1. **Single Source of Truth**: The rules are maintained in one location (`ai/tamanu_source_dbt_rules.md`)
2. **Automatic Updates**: Changes to the original file are immediately reflected in the linked locations
3. **No Duplication**: Avoids having multiple copies of the same file that could get out of sync
4. **Version Control**: Only the original file needs to be tracked in git

## Verification

After creating the link, verify it's working by checking that the content is accessible:

```bash
# Check the content is accessible through the link
cat .clinerules/tamanu_source_dbt_rules.md
# or
cat .cursor/rules/tamanu_source_dbt_rules.md
```

The content should match the original file in `ai/tamanu_source_dbt_rules.md`.

## Troubleshooting

### Windows Symbolic Link Issues

If you encounter permission errors when creating symbolic links on Windows, use hard links instead:
- Hard links work without administrator privileges
- They provide the same functionality for files (not directories)
- Use `-ItemType HardLink` instead of `-ItemType SymbolicLink`

### File Not Found Errors

Ensure the paths are correct relative to your current working directory:
- The target path should point to the actual location of `ai/tamanu_source_dbt_rules.md`
- Use forward slashes (`/`) on macOS/Linux and backslashes (`\`) on Windows PowerShell

## Current Setup

This repository already has the Cline rules set up:
- Original rules file: `ai/tamanu_source_dbt_rules.md`
- Cline rules link: `.clinerules/tamanu_source_dbt_rules.md`

The link is already created and ready to use with Cline.
