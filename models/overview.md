{% docs __overview__ %}
# Tamanu models documentation

## Purpose
This documentation aims to be a guide to Tamanu's standard models. The expected use-case is a developer or data steward looking up a particular model for information on how to use it.

## Scope
Models included in this documentation:
- sources (raw public schema)
- bases (reporting schema)
- datasets (reporting schema)

## Content

### Raw public schema
The models in the "sources" folder represents the models in the operational database. Tags are used to classify the data and operational status of the models.

Data type tag:
- administration - System operation data that changes during normal use (e.g. user passwords, email addresses)
- clinical - Patient medical records. Always attached to a Patient, often via an Encounter. Always considered sensitive
- financial - Patient billing, invoicing, and payment for services and goods provided. Sometimes sensitive
- log - System generated records that capture events, actions or state changes within an application.
- patient - Patient demographic information. Can be masked or aggregated for privacy in reporting
- reference - System-wide configuration and lists (diagnoses, facilities, locations, surveys, vaccination schedules). Populated centrally, synced to all facilities. Never sensitive/restricted
- system - Internal Tamanu operation data (configuration, sync status, task queues). Usually invisible to clinicians. Sometimes sensitive. Not available for reporting

Identifier type tag:
- direct_identifier - Identifiers that can uniquely identify an individual on their own (e.g full name, email, passport ID). These identifiers are excluded from data analysis.
- quasi_identifier - Identifiers that are not uniquely identifying alone, but can identify an individual when combined (e.g. sex, location). These identifiers are to be aggregated or generalised for data analysis.

Operational status tag:
- deprecated - Models that are no longer in use, data from these models are usually migrated to another part of the database. These models will not be available for reporting.

### Reporting schema
The models in the "bases" folder have been stripped of metadata relevant to an operational database as well as test patient and deleted data. The models from this schema is used to build reports.

The models in the "reports" folder have been flattened for ease of creating reports. These models are used in the standardised reports that are made available to users on Tamanu's facility servers.

## Exploring the documentation

### Navigation
You can use the Project and Database navigation tabs on the left side of the window to explore the models in your project.

### Project Tab
The Project tab mirrors the directory structure of your dbt project. In this tab, you can see all of the models defined in your dbt project, as well as models imported from dbt packages.

### Database Tab
The Database tab also exposes your models, but in a format that looks more like a database explorer. This view shows relations (tables and views) grouped into database schemas. Note that ephemeral models are not shown in this interface, as they do not exist in the database.

### Graph Exploration
You can click the blue icon on the bottom-right corner of the page to view the lineage graph of your models.

On model pages, you'll see the immediate parents and children of the model you're exploring. By clicking the Expand button at the top-right of this lineage pane, you'll be able to see all of the models that are used to build, or are built from, the model you're exploring.

Once expanded, you'll be able to use the --select and --exclude model selection syntax to filter the models in the graph. For more information on model selection, check out the dbt docs.

Note that you can also right-click on models to interactively filter and explore the graph.
{% enddocs %}
