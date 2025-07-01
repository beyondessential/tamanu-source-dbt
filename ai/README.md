# AI Rules for tamanu-source-dbt

This directory contains AI rules and guidelines for working with the tamanu-source-dbt project.

## Setting up AI Rules for Cline

To use these AI rules with Cline or Cursor, you need to create a symbolic link (or hard link on Windows) to make the rules accessible to your AI assistant.

### For Cline

Cline looks for rules in the `.clinerules` directory. Create a junction/symbolic link to the entire `ai` directory as follows:

#### On Windows (Command Prompt)

```cmd
# Create a junction link (doesn't require admin privileges)
mklink /J .clinerules ai
```

#### On Windows (PowerShell - Alternative method)

```powershell
# Create individual hard links if junction is not preferred
New-Item -ItemType Directory -Path ".clinerules" -Force
New-Item -ItemType HardLink -Path ".clinerules\tamanu_source_dbt_rules.md" -Target "ai\tamanu_source_dbt_rules.md"
```

#### On macOS/Linux

```bash
# Create a symbolic link to the entire ai directory
ln -s ai .clinerules
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

