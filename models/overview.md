{% docs __overview__ %}
# Tamanu Models Documentation

## Purpose
This documentation serves as a guide to Tamanu's standard models for developers, data stewards, and analysts looking to understand and utilise the data structure for reporting and analytics.

## Project Overview
This dbt project transforms Tamanu healthcare system data into optimised datasets following a structured data flow: **sources/logs → bases → datasets → reports**. The architecture supports both reporting and analytics use cases while maintaining data governance and privacy standards.

## Model Architecture & Data Flow

### Layer 1: Sources & Logs
- **`models/sources`**: Raw operational database tables from the `public` schema
- **`models/logs`**: System-generated audit and event data from the `logs` schema
- **Purpose**: Foundation layer representing the operational database structure
- **Status**: Read-only definitions managed externally

### Layer 2: Bases
- **`models/bases`**: Cleaned and filtered source data with soft-deleted records and test patients removed
- **Purpose**: Clean, reliable foundation for all downstream transformations
- **Usage**: Building block for datasets and reports

### Layer 3: Datasets
- **`models/datasets`**: Business-ready, denormalised views built on bases models
- **Features**: User-friendly column names, joined data, calculated fields
- **Purpose**: Optimised for data analysis and report development
- **Target Audience**: Data analysts and report developers

### Layer 4: Reports
- **`models/reports`**: Final reporting layer with translations and formatting applied
- **Features**: 
  - Localised field labels using the translation system
  - Standardised date/time formatting
  - Optimised for end-user consumption
- **Configuration**: Each report includes a corresponding `.json` config file in `models/reports/config/`

## Deployment Targets

### Reporting Schema
**Command**: `dbt run --target reporting_release`
- Complete functionality with all models and columns
- Full data fidelity for comprehensive reporting
- Used for standardised reports on Tamanu facility servers

### Analytics Schema (Tupaia Integration)
**Command**: `dbt run --target analytics --select tag:base +tag:metrics`
- Builds the base layer plus the metrics Tupaia reads from `public_tupaia`; the
  leading `+` pulls in the clinical and intermediate models each metric depends on
- Preserves all transformations and business logic
- Optimised for aggregated analysis and population health insights
- Masking of direct identifiers is applied to the replica, not by dbt

## Data Classification System

### Data Type Tags
- **`administration`** - System operation data that changes during normal use (e.g., user passwords, email addresses)
- **`clinical`** - Patient medical records, always attached to a Patient (often via an Encounter), always considered sensitive
- **`financial`** - Patient billing, invoicing, and payment for services and goods provided, sometimes sensitive
- **`log`** - System-generated records capturing events, actions, or state changes within the application
- **`patient`** - Patient demographic information, can be masked or aggregated for privacy in reporting
- **`reference`** - System-wide configuration and lists (diagnoses, facilities, locations, surveys, vaccination schedules), populated centrally and synced to all facilities, never sensitive/restricted
- **`system`** - Internal Tamanu operation data (configuration, sync status, task queues), usually invisible to clinicians, sometimes sensitive, not available for reporting

### Privacy Classification Tags
- **`direct_identifier`** - Identifiers that can uniquely identify an individual on their own (e.g., full name, email, passport ID)
  - Classification metadata only; masking of these identifiers is applied to the replica, not by dbt
- **`quasi_identifier`** - Identifiers that are not uniquely identifying alone but can identify an individual when combined (e.g., sex, location)
  - These identifiers should be aggregated or generalised for data analysis

### Operational Status Tags
- **`deprecated`** - Models that are no longer in use; data from these models is usually migrated to another part of the database
  - These models will not be available for reporting

## Extensions & Customisations

### Survey Models
Survey models are not part of the standard model set but are available as extensions in individual project deployments. These handle:
- Custom form-based data collection
- Patient-specific survey responses
- Program-specific data elements

Survey models follow the same architectural patterns as standard models when implemented.

## Exploring the Documentation

### Navigation Options

#### Project Tab
The Project tab mirrors the directory structure of your dbt project, showing all models defined in the project as well as models imported from dbt packages.

#### Database Tab
The Database tab presents models in a database explorer format, showing relations (tables and views) grouped into database schemas. Note that ephemeral models are not shown in this interface as they do not exist in the database.

### Lineage Graph Exploration
Click the blue icon on the bottom-right corner of any page to view the lineage graph of your models.

#### Model Page Lineage
On individual model pages, you'll see the immediate parents and children of the model you're exploring. Click the **Expand** button at the top-right of the lineage pane to see all models that are used to build, or are built from, the current model.

#### Interactive Graph Features
- Use `--select` and `--exclude` model selection syntax to filter models in the graph
- Right-click on models to interactively filter and explore the graph
- Navigate through the complete data lineage to understand dependencies

{% enddocs %}
