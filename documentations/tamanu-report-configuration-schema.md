# Tamanu Report Configuration Schema

This documentation describes the JSON schema for Tamanu report configuration files. The schema defines the structure and validation rules that all report configurations must follow to ensure compatibility with the Tamanu reporting system.

## Overview

The Tamanu Report Configuration Schema is a JSON Schema (draft-07) that validates report configuration files used in the Tamanu healthcare system. Each report configuration file defines how a report should be executed, what parameters it accepts, and how it integrates with the reporting interface.

## Configuration File Structure

### Root Level Properties

Every report configuration file must be a valid JSON object with the following structure:

#### Required Properties

- **`query`** (string): The SQL query or placeholder for the report. Must be at least 1 character long.
- **`name`** (string): Display name of the report as shown in the Tamanu reporting interface. Every report must define a `name` at the **root level**. The JSON schema enforces this as a required root-level property (`minLength: 1`). A legacy `name` under `queryOptions` is still permitted but deprecated.
- **`status`** (enum): Publication status of the report. Must be either `"draft"` or `"published"`.
- **`dbSchema`** (enum): Database schema to use for the report. Must be `"reporting"`.
- **`queryOptions`** (object): Configuration options for the report query (see detailed structure below).

#### Optional Properties

- **`notes`** (string): Detailed description and notes about the report's purpose and functionality.
- **`reportDefinitionId`** (string): Unique identifier for the report definition.
- **`dhis2DataSet`** (string): DHIS2 dataset identifier. Must be a valid DHIS2 UID — 11 characters matching the pattern `^[a-zA-Z][a-zA-Z0-9]{10}$` (a letter followed by 10 alphanumerics).

### Recommended Field Ordering

For consistency across all report configuration files, define properties in the following order. This applies to both `standard` and `sensitive` reports.

**Root level:**

1. `query`
2. `name`
3. `status`
4. `notes`
5. `dbSchema`
6. `reportDefinitionId` *(if present)*
7. `dhis2DataSet` *(if present)*
8. `queryOptions`

**Within `queryOptions`:**

1. `defaultDateRange`
2. `dateRangeLabel` *(if present)*
3. `dataSources`
4. `parameters`

**Within each parameter object:**

1. `parameterField`
2. `label`
3. `name`
4. Type-specific properties (e.g. `suggesterEndpoint`, `suggesterOptions`, `options`, `filterBySelectedFacility`)

Use 2-space indentation throughout.

### Query Options Structure

The `queryOptions` object defines how the report behaves and what parameters it accepts:

#### Required Properties

- **`dataSources`** (array): Available data sources for the report. Must contain at least one of:
  - `"thisFacility"` - Report runs for the currently selected facility
  - `"allFacilities"` - Report runs across all facilities
  - Both options can be included to allow user selection
- **`defaultDateRange`** (enum): Default date range for the report. Options:
  - `"allTime"` - No date restriction
  - `"24hours"` - Last 24 hours
  - `"7days"` - Last 7 days
  - `"30days"` - Last 30 days
  - `"18years"` - Last 18 years (typically for paediatric reports)
  - `"next30days"` - Next 30 days (for future appointments/schedules)
- **`parameters`** (array): List of parameter configurations that define user inputs for the report

#### Default Date Range Examples

For a report generated on **2025-07-01 12:00:00**, the default date ranges would resolve to:

- **`"allTime"`**: From 1970-01-01 00:00:00 to 2025-07-01 12:00:00 
- **`"24hours"`**: From 2025-06-30 12:00:00 to 2025-07-01 12:00:00
- **`"7days"`**: From 2025-06-24 00:00:00 to 2025-07-01 12:00:00
- **`"30days"`**: From 2025-06-01 00:00:00 to 2025-07-01 12:00:00
- **`"18years"`**: From 2007-07-01 00:00:00 to 2025-07-01 12:00:00
- **`"next30days"`**: From 2025-07-02 00:00:00 to 2025-08-01 23:59:59

#### Optional Properties

- **`dateRangeLabel`** (string): Custom label for the date range input field
- **`name`** (string): *(legacy)* Display name nested under `queryOptions`. New and existing reports should define the display name as a **root-level** `name` property instead (see [Required Properties](#required-properties)). This nested field is retained only for backwards compatibility and should not be used.

## Parameter Types

The schema supports various parameter types to handle different kinds of user inputs:

### 1. FacilityField

Allows users to select a facility from available options.

```json
{
  "parameterField": "FacilityField",
  "label": "Facility",
  "name": "facilityId",
  "filterBySelectedFacility": true
}
```

**Properties:**
- `filterBySelectedFacility` (boolean, optional): Whether to filter options by the currently selected facility

### 2. ParameterAutocompleteField

Provides autocomplete functionality using predefined API endpoints.

```json
{
  "parameterField": "ParameterAutocompleteField",
  "label": "Department",
  "name": "departmentId",
  "suggesterEndpoint": "department",
  "suggesterOptions": {
    "baseQueryParameters": {
      "filterByFacility": true
    }
  }
}
```

**Required Properties:**
- `suggesterEndpoint` (string): API endpoint for fetching suggestions

**Optional Properties:**
- `suggesterOptions` (object): Additional configuration for the suggester
  - `baseQueryParameters` (object): Base query parameters
    - `filterByFacility` (boolean): Filter suggestions by facility

**Available Suggester Endpoints:**
- `allergy`, `angiogramImagingArea`, `appointmentType`, `arrivalMode`, `bookableLocationGroup`
- `bookingType`, `carePlan`, `catchment`, `colonoscopyImagingArea`, `contactRelationship`
- `country`, `ctScanImagingArea`, `department`, `designation`, `diagnosis`
- `diet`, `dischargeDisposition`, `diseaseCoding`, `division`, `drug`
- `ecgImagingArea`, `echocardiogramImagingArea`, `encounter`, `endoscopyImagingArea`, `ethnicity`
- `facility`, `facilityLocationGroup`, `familyRelation`, `fluroscopyImagingArea`, `holterMonitorImagingArea`
- `imagingType`, `insurer`, `invoiceInsurancePlan`, `invoicePriceList`, `invoiceProduct`
- `labSampleSite`, `labTestCategory`, `labTestLaboratory`, `labTestMethod`, `labTestPanel`
- `labTestPriority`, `labTestType`, `location`, `locationGroup`, `mammogramDiagImagingArea`
- `mammogramImagingArea`, `mammogramScreenImagingArea`, `manufacturer`, `medicalArea`, `medicationNotGivenReason`
- `medicationSet`, `medicationTemplate`, `mriImagingArea`, `multiReferenceData`, `nationality`
- `nonSensitiveLabTestCategory`, `noteType`, `nursingZone`, `occupation`, `orthopantomographyImagingArea`
- `patient`, `patientBillingType`, `patientFieldDefinitionCategory`, `patientLabTestCategories`, `patientLabTestPanelTypes`
- `paymentMethod`, `placeOfBirth`, `practitioner`, `procedureType`, `programRegistry`
- `programRegistryClinicalStatus`, `programRegistryCondition`, `reaction`, `referenceData`, `referralSource`
- `religion`, `reportDefinition`, `role`, `secondaryIdType`, `sensitiveLabTestCategory`
- `settlement`, `specimenType`, `stressTestImagingArea`, `subdivision`, `survey`
- `taskDeletionReason`, `taskNotCompletedReason`, `taskSet`, `taskTemplate`, `template`
- `timeZone`, `triageReason`, `ultrasoundImagingArea`, `vaccineCircumstance`, `vaccineNotGivenReason`
- `vascularStudyImagingArea`, `village`, `xRayImagingArea`

### 3. ParameterMultiselectField

Allows users to select multiple options from a predefined list.

```json
{
  "parameterField": "ParameterMultiselectField",
  "label": "Admission status",
  "name": "admissionStatus",
  "options": [
    {
      "label": "Active",
      "value": "active"
    },
    {
      "label": "Discharged",
      "value": "discharged"
    }
  ]
}
```

**Required Properties:**
- `options` (array): List of available options, each with:
  - `label` (string): Display text for the option
  - `value` (string): Internal value for the option

### 4. ParameterSelectField

Allows users to select a single option from a predefined list.

```json
{
  "parameterField": "ParameterSelectField",
  "label": "Status",
  "name": "statusId",
  "options": [
    {
      "label": "Pending",
      "value": "pending"
    },
    {
      "label": "Completed",
      "value": "completed"
    }
  ]
}
```

**Required Properties:**
- `options` (array): List of available options with the same structure as ParameterMultiselectField

### 5. Specialised Field Types

The following field types are available for specific use cases and don't require additional configuration beyond the base parameter properties:

- **`AppointmentTypeField`** - For appointment type selection
- **`BookingTypeField`** - For booking type selection
- **`DiagnosisField`** - For diagnosis selection
- **`EmptyField`** - For empty/placeholder fields
- **`ImagingTypeField`** - For imaging type selection
- **`LabTestCategoryField`** - For lab test category selection
- **`LabTestCategorySensitiveField`** - For sensitive lab test category selection
- **`LabTestLaboratoryField`** - For lab test laboratory selection
- **`LabTestTypeField`** - For lab test type selection
- **`LocationField`** - For location selection
- **`ParameterSuggesterSelectField`** - For suggester-based select fields
- **`PatientField`** - For patient selection
- **`PractitionerField`** - For practitioner selection
- **`VaccineCategoryField`** - For vaccine category selection
- **`VaccineField`** - For vaccine selection
- **`VillageField`** - For village selection

### Common Parameter Properties

All parameter types share these required properties:

- **`parameterField`** (string): The type of parameter field (must match one of the supported types)
- **`label`** (string): Display label for the parameter (minimum 1 character)
- **`name`** (string): Internal identifier for the parameter (must start with a letter and contain only letters, numbers, and underscores)

## Validation Rules

The schema enforces the following validation rules:

1. **Required Fields**: All required properties must be present at their respective levels
2. **Enum Constraints**: `status`, `dbSchema`, `defaultDateRange`, and `dataSources` must use predefined values
3. **Parameter Type Validation**: Each parameter type has specific required and optional properties
4. **Name Pattern**: Parameter names must match the pattern `^[a-zA-Z][a-zA-Z0-9_]*$`
5. **Unique Data Sources**: The `dataSources` array cannot contain duplicate values
6. **Conditional Requirements**: 
   - `ParameterAutocompleteField` requires `suggesterEndpoint`
   - `ParameterMultiselectField` and `ParameterSelectField` require `options` array
7. **No Additional Properties**: Parameter objects cannot contain properties not defined in the schema
8. **Minimum Array Length**: `dataSources` and `options` arrays must contain at least one item

## Complete Example

Here's a comprehensive example of a valid report configuration:

```json
{
  "query": "SELECT p.display_id, p.first_name, p.last_name, e.start_date FROM patients p JOIN encounters e ON p.id = e.patient_id WHERE e.start_date >= :startDate AND e.start_date <= :endDate AND (:facilityId IS NULL OR e.location_id IN (SELECT id FROM locations WHERE facility_id = :facilityId)) AND (:departmentId IS NULL OR e.department_id = :departmentId)",
  "name": "Patient Encounters Report",
  "status": "published",
  "notes": "Patient encounter report showing all encounters within the selected date range, with optional filtering by facility and department. Useful for tracking patient flow and departmental activity.",
  "dbSchema": "reporting",
  "reportDefinitionId": "patient-encounters-detailed",
  "dhis2DataSet": "abcdefghijk",
  "queryOptions": {
    "defaultDateRange": "30days",
    "dateRangeLabel": "Encounter date range",
    "dataSources": ["thisFacility", "allFacilities"],
    "parameters": [
      {
        "parameterField": "FacilityField",
        "label": "Facility",
        "name": "facilityId",
        "filterBySelectedFacility": true
      },
      {
        "parameterField": "ParameterAutocompleteField",
        "label": "Department",
        "name": "departmentId",
        "suggesterEndpoint": "department",
        "suggesterOptions": {
          "baseQueryParameters": {
            "filterByFacility": true
          }
        }
      },
      {
        "parameterField": "ParameterSelectField",
        "label": "Encounter Type",
        "name": "encounterType",
        "options": [
          {
            "label": "Inpatient",
            "value": "inpatient"
          },
          {
            "label": "Outpatient",
            "value": "outpatient"
          },
          {
            "label": "Emergency",
            "value": "emergency"
          }
        ]
      }
    ]
  }
}
```
