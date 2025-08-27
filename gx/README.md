# Great Expectations Scripts

This directory contains separate scripts for Great Expectations setup and validation operations.

## Scripts Overview

### 🔧 `setup.py` - Setup and Configuration
Sets up Great Expectations assets, expectation suites, and validation definitions.

**Usage:**
```bash
# Basic setup
python gx/setup.py

# Setup with batch refresh
python gx/setup.py --refresh-batches

# Setup with custom datasource
python gx/setup.py --datasource my_datasource
```

**What it does:**
- Creates data assets and batch definitions for all datasets
- Loads and reloads Python expectation suites
- Creates validation definitions and checkpoint
- Builds data docs
- Provides detailed setup summary

### ✅ `validate.py` - Run Validations
Executes validations and generates detailed reports.

**Usage:**
```bash
# Basic validation
python gx/validate.py

# Validation without opening browser
python gx/validate.py --no-browser

# Validation without building docs
python gx/validate.py --no-docs

# Custom checkpoint and output file
python gx/validate.py --checkpoint my_checkpoint --output my_results.json
```

**What it does:**
- Runs the specified checkpoint
- Extracts and displays detailed validation results
- Builds and opens data docs (optional)
- Saves complete results to JSON file
- Returns appropriate exit codes (0 for success, 1 for failure)

## Recommended Workflow

1. **Initial Setup:**
   ```bash
   python gx/setup.py --refresh-batches
   ```

2. **Run Validations:**
   ```bash
   python gx/validate.py
   ```

3. **CI/CD Integration:**
   ```bash
   # Setup (run once or when schemas change)
   python gx/setup.py
   
   # Validate (run regularly)
   python gx/validate.py --no-browser
   echo "Exit code: $?"
   ```

## Key Features

### Setup Script (`setup.py`)
- ✅ Modular setup without running validations
- ✅ Configurable datasource selection
- ✅ Optional batch definition refresh
- ✅ Clear setup summary with counts
- ✅ Guidance for next steps

### Validation Script (`validate.py`)
- ✅ Focused validation execution
- ✅ Detailed validation results with statistics
- ✅ Configurable output options
- ✅ Proper exit codes for automation
- ✅ Optional data docs generation

## Output Files

- `complete_validation_results.json` - Detailed validation results
- `gx/uncommitted/data_docs/` - Generated HTML reports
- Console output with formatted summaries and statistics

## Error Handling

Both scripts handle database connection issues gracefully and provide meaningful error messages. The validation script returns appropriate exit codes for automation scenarios.
