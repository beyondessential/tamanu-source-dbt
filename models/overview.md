{% docs __overview__ %}
# Tamanu models documentation

## Purpose
This documentation aims to be a guide to Tamanu's standard models. The expected use-case is a developer or data steward looking up a particular model for information on how to use it.

## Scope
Models included in this documentation:
- sources
- bases
- datasets
- reporting schema

## Content

### Raw schema
The models in the "sources" folder represents the models in the operational database. Tags are used to classify the data and operational status of the models.

Data type tag:
- administration - Thematically pretty close to reference data, but distinct in that adminisstration data is expected to change as part of normal day-to-day system operation (e.g. a user can change their password and email address outside of a project manager or admin reconfiguring the system).
- clinical - Patient medical records. Always attached to a Patient, often via an Encounter (almost all records with a `patientId` or an `encounterId` will be clinical data). Always considered sensitive.
- patient - Patient demographic information. These can be masked or aggregated where appropriate for patient privacy in reporting.
- reference - System-wide configuration, lists (e.g. diagnoses, facilities, locations). Also includes surveys and their questions, vaccination schedules. Populated centrally, synced down to all facilities and mobile devices. Never considered senstive/restricted.
- system - Data that is internal to Tamanu operation. Local configuration, sync status, task queues etc. Usually invisible to clinicians and PMs. Sometimes sensitive (e.g. a queued email to a patient notifying them of a test result). These models will not be available for reporting.

Operational status tag:
- deprecated - Models that are no longer in use, data from these models are usually migrated to another part of the database. These models will not be available for reporting.

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
