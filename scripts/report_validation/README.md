# Tamanu Report Configuration Schema

This directory contains the JSON schema and validation tools for Tamanu report configuration files.

## Files

- `report-config-schema.json` - JSON Schema for validating report configuration files
- `README.md` - This documentation file

## Report Configuration Files

The actual report configuration files are located in `models/reports/config/` directory.

## Schema Overview

The JSON schema defines the structure and validation rules for Tamanu report configuration files. Each report configuration must include:

### Required Fields

- **query** (string): SQL query or placeholder for the report
- **status** (enum): Publication status - `"draft"` or `"published"`
- **dbSchema** (enum): Database schema - `"raw"` or `"reporting"`
- **queryOptions** (object): Configuration options for the report query

### Optional Fields

- **notes** (string): Detailed description and notes about the report
- **reportDefinitionId** (string): ID for the report definition

### Query Options Structure

The `queryOptions` object must contain:

- **dataSources** (array): Available data sources - `["thisFacility"]`, `["allFacilities"]`, or both
- **defaultDateRange** (enum): Default date range - `"allTime"`, `"24hours"`, `"7days"`, `"30days"`, `"18years"`, or `"next30days"`
- **parameters** (array): List of parameter configurations

Optional fields:
- **dateRangeLabel** (string): Custom label for the date range input
- **name** (string): Name of the report

### Parameter Types

The schema supports multiple types of parameters:

#### 1. FacilityField
```json
{
  "parameterField": "FacilityField",
  "label": "Facility",
  "name": "facilityId",
  "filterBySelectedFacility": true
}
```

#### 2. ParameterAutocompleteField
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

Supported suggester endpoints:
- `additionalInvoiceProduct`
- `allergy`
- `angiogramImagingArea`
- `appointmentType`
- `arrivalMode`
- `bookableLocationGroup`
- `carePlan`
- `catchment`
- `colonoscopyImagingArea`
- `condition`
- `contactRelationship`
- `country`
- `ctScanImagingArea`
- `department`
- `designation`
- `diagnosis`
- `diet`
- `dischargeDisposition`
- `diseaseCoding`
- `division`
- `drug`
- `ecgImagingArea`
- `echocardiogramImagingArea`
- `endoscopyImagingArea`
- `ethnicity`
- `facility`
- `facilityLocationGroup`
- `familyRelation`
- `fluroscoptyImagingArea`
- `holterMonitorImagingArea`
- `imagingType`
- `insurer`
- `invoiceProducts`
- `labSampleSite`
- `labTestCategory`
- `labTestLaboratory`
- `labTestMethod`
- `labTestPanel`
- `labTestPriority`
- `labTestType`
- `location`
- `locationGroup`
- `mammogramDiagImagingArea`
- `mamogramImagingArea`
- `mamogramScreenImagingArea`
- `manufacturer`
- `medicalArea`
- `mriImagingArea`
- `multiReferenceData`
- `nationality`
- `nonSensitiveLabTestCategory`
- `nursingZone`
- `occupation`
- `orthopantomographyImagingArea`
- `patient`
- `patientBillingType`
- `patientLabTestCategories`
- `patientLabTestPanelTypes`
- `patientType`
- `paymentMethod`
- `placeOfBirth`
- `practitioner`
- `procedureType`
- `programRegistry`
- `programRegistryClinicalStatus`
- `programRegistryCondition`
- `reaction`
- `referralSource`
- `religion`
- `secondaryIdType`
- `sensitiveLabTestCategory`
- `settlement`
- `specimenTest`
- `stressTestImagingArea`
- `subdivision`
- `survey`
- `taskDeletionReason`
- `taskNotCompletedReason`
- `taskSet`
- `taskTemplate`
- `template`
- `triageReason`
- `ultrasoundImagingArea`
- `vaccine`
- `vaccineCircumstance`
- `vaccineNotGivenReason`
- `vascularStudyImagingArea`
- `village`
- `xRayImagingArea`

#### 3. ParameterMultiselectField
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

#### 4. ParameterSelectField
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

#### 5. Specialised Field Types
The schema also supports specialized field types that don't require additional configuration:

- `AppointmentTypeField` - For appointment type selection
- `BookingTypeField` - For booking type selection
- `DiagnosisField` - For diagnosis selection
- `EmptyField` - For empty/placeholder fields
- `ImagingTypeField` - For imaging type selection
- `LabTestCategoryField` - For lab test category selection
- `LabTestCategorySensitiveField` - For sensitive lab test category selection
- `LabTestLaboratoryField` - For lab test laboratory selection
- `LabTestTypeField` - For lab test type selection
- `LocationField` - For location selection
- `ParameterSuggesterSelectField` - For suggester-based select fields
- `PatientField` - For patient selection
- `PractitionerField` - For practitioner selection
- `VaccineCategoryField` - For vaccine category selection
- `VaccineField` - For vaccine selection
- `VillageField` - For village selection

## Validation

### Using the Python Script

A validation script is provided at `scripts/validate_report_configs.py` to validate all configuration files against the schema.

**Prerequisites:**
```bash
pip install jsonschema
```

**Usage:**
```bash
# From the project root directory
python scripts/validate_report_configs.py
```

The script will:
1. Load the JSON schema
2. Find all JSON configuration files in this directory
3. Validate each file against the schema
4. Report validation results and errors

## Schema Rules

1. **Required Fields**: All required fields must be present
2. **Enum Values**: Status and dbSchema must use predefined values
3. **Parameter Validation**: Each parameter type has specific required fields
4. **Name Pattern**: Parameter names must start with a letter and contain only letters, numbers, and underscores
5. **Unique Data Sources**: Data sources array cannot contain duplicates
6. **Conditional Requirements**: 
   - `ParameterAutocompleteField` requires `suggesterEndpoint`
   - `ParameterMultiselectField` and `ParameterSelectField` require `options` array
7. **No Additional Properties**: Extra fields not defined in the parameter schema are not allowed (report level allows additional properties)

## Example Configuration

```json
{
  "query": "SELECT * FROM patients WHERE created_at >= :startDate",
  "status": "published",
  "notes": "Lists all patients registered within the selected date range",
  "dbSchema": "reporting",
  "queryOptions": {
    "name": "Patient Registration Report",
    "defaultDateRange": "7days",
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
      }
    ]
  }
}
```

## Contributing

When adding new report configurations:

1. Follow the schema structure exactly
2. Use meaningful names and labels
3. Add descriptive notes explaining the report purpose
4. Validate your configuration using the provided script
5. Test the report functionality before committing

## Schema Updates

If you need to modify the schema:

1. Update `report-config-schema.json`
2. Update this README documentation
3. Run validation script to ensure existing configs still pass
4. Update any configs that need changes for the new schema
5. Consider backward compatibility implications
