# List of Tamanu reports
## Standard
### Admissions line list

**Report Description**

This report generates a list of all patients with a hospital admission started within the selected date range. The report includes both active and discharged admissions. Patients are listed in order of most recent admission by admission date and time. The discharge date is displayed if the patient has been discharged, 
otherwise if the encounter is active this column will appear blank. 

The below information is included for each hospital admission:
- List of all assigned departments and the date and time a patient was assigned to each department.
- List of all assigned areas and the date and time a patient was assigned to each area.
- List of all assigned locations and the date and time a patient was assigned to each location.
- List of all primary and secondary diagnoses (including code) with a certainty of 'Confirmed' and 'Suspected'. Diagnoses with a certainty of 'Disproven' or 'Recorded in error' are excluded. 


**Filters**

Facility, Patient billing type, Admitting clinician, Area, Department, Admission status

**Default date range**: 7days


---

### Deceased patients line list

**Report Description**

This report generates a list of all deceased patients within the selected parameters. Patients are listed in chronological order by date and time of death. 
The report includes all details documented in the patient death record. 

**Filters**

Facility, Cause of death, Due to (or as a consequence of), Other contributing condition, Manner of death

**Default date range**: 7days


---

### Encounter diets line list

**Report Description**

This report generates a list of all active encounters with their associated dietary requirements. The report includes:
- Patient details and current location
- Dietary requirements and restrictions.

**Filters**

Facility, Area

**Default date range**: allTime


---

### Hospital admissions by area summary

**Report Description**

This report provides a statistical summary of hospital admissions by area for the selected parameters. Indicators are reported chronologically by month. E.g. if user selects range 10/01/23-20/02/23 the report should pull in all details for whole of January (Jan 1 to Jan 31) and partial details for Feb (Feb 1 to Feb 20). 

Details on how each indicator is calculated are provided below:
- Number of admissions = Number of hospital admissions for specified month by area. Where area is the last area the patient was located prior to discharge/at reporting. 
- Number of discharges = Number of patients discharged from a hospital admission for specified month by area. Where area is the last area the patient was located prior to discharge. 
- Number of deaths = Number of deceased patients that had an active hospital admission for specified month by area when their death was recorded. Where area is the last area the patient was located prior to death. 
- Number of transfers into area = Number of patients assigned to area during a hospital admission for the specified month. 
- Number of transfers out of area = Number of patients moved from area to another area during a hospital admission for the specified month.
- Average length of stay: LOS for single patient = Date of discharge - Date of admission. If these are the same dates, then LOS = 1. Therefore, ALOS = (Sum of LOS for patients discharged in specified month by area)/(Number of patients discharged in specified month by area). ALOS is reported to the accuracy of tenths, i.e. 0.1. Source - https://gateway.euro.who.int/en/indicators/hfa_540-6100-average-length-of-stay-all-hospitals/#:~:text=Total%20number%20of%20occupied%20hospital,is%20set%20to%20one%20day
- Number of patient days = Total number of days patients are assigned to the specified area. 
- Number of beds = Number of locations within an area (as per deployment configuration). This excludes locations that have a status of historical or no maximum occupancy (i.e. max occupancy does not equal 1). 
- Bed occupancy (%) = (Number of patient days in specified month by area / (Number of locations in area * Days in month)) * 100. Only locations with a max occupancy of 1 are included in number of locations in area count. If report is generated part way through a month, e.g. report generated on the 15th of March that includes March statistics, Days in month = 15. Note that it is possible for bed occupancy to be greater than 100% if a patient is admitted and discharge on the same day and another patient is admitted to the same bed on that same day. Bed occupancy (%) is reported to the accuracy of tenths, i.e. 0.1. Source - https://gateway.euro.who.int/en/indicators/hfa_542-6210-bed-occupancy-rate-acute-care-hospitals-only/.

**Filters**

Facility, Area

**Default date range**: 30days


---

### Hospital admissions by department summary

**Report Description**

This report provides a statistical summary of hospital admissions by department for the selected parameters. Indicators are reported chronologically by month. E.g. if user selects range 10/01/23 -20/02/23 the report should pull in all details for whole of January (Jan 1 to Jan 31) and partial details for Feb (Feb 1 to Feb 20). 

Details on how each indicator is calculated are provided below:
- Number of admissions = Number of hospital admissions for specified month by department. Where department is the last department the patient was assigned prior to discharge/at reporting. 
- Number of discharges = Number of patients discharged from a hospital admission for specified month by department. Where department is the last department the patient was assigned prior to discharge. 
- Number of deaths = Number of deceased patients that had an active hospital admission for specified month by department when their death was recorded. Where department is the last department the patient was assigned prior to death. 
- Number of transfers into department = Number of patients assigned to department during a hospital admission for the specified month. 
- Number of transfers out of department = Number of patients moved from department to another department during a hospital admission for the specified month.
- Average length of stay: LOS for single patient = Date of discharge - Date of admission. If these are the same dates, then LOS = 1. Therefore, ALOS = (Sum of LOS for patients discharged in specified month by department)/(Number of patients discharged in specified month by department). ALOS is reported to the accuracy of tenths, i.e. 0.1. Source - https://gateway.euro.who.int/en/indicators/hfa_540-6100-average-length-of-stay-all-hospitals/#:~:text=Total%20number%20of%20occupied%20hospital,is%20set%20to%20one%20day

**Filters**

Facility, Department

**Default date range**: 30days


---

### Hospital admissions by location summary

**Report Description**

This report provides a statistical summary of hospital admissions by location for the selected parameters. Statistics are reported chronologically by month. E.g. if user selects range 10/01/23 -20/02/23 the report should pull in all details for whole of January (Jan 1 to Jan 31) and partial details for Feb (Feb 1 to Feb 20). 

Details on how each indicator is calculated are provided below:
- Number of admissions = Number of hospital admissions for specified month by location. Where location is the last area the patient was located prior to discharge/at reporting. 
- Number of discharges = Number of patients discharged from a hospital admission for specified month by area. Where area is the last area the patient was located prior to discharge. 
- Number of deaths = Number of deceased patients that had an active hospital admission for specified month by area when their death was recorded. Where area is the last area the patient was located prior to death. 
- Number of transfers into area = Number of patients assigned to area during a hospital admission for the specified month. 
- Number of transfers out of area = Number of patients moved from area to another area during a hospital admission for the specified month.
- Average length of stay: LOS for single patient = Date of discharge - Date of admission. If these are the same dates, then LOS = 1. Therefore, ALOS = (Sum of LOS for patients discharged in specified month by area)/(Number of patients discharged in specified month by area). ALOS is reported to the accuracy of tenths, i.e. 0.1. Source - https://gateway.euro.who.int/en/indicators/hfa_540-6100-average-length-of-stay-all-hospitals/#:~:text=Total%20number%20of%20occupied%20hospital,is%20set%20to%20one%20day
- Number of patient days = Number of days of active hospital admissions for the specified month by area. Where day of patient admission = day 1. 
- Number of beds = Number of locations within an area (as per deployment configuration). This excludes locations that have a status of historical or no maximum occupancy (i.e. max occupancy does not equal 1). 
- Bed occupancy (%) = (Number of patient days in specified month by area / (Number of locations in area * Days in month)) * 100. Only locations with a max occupancy of 1 are included in number of locations in area count. If report is generated part way through a month, e.g. report generated on the 15th of March that includes March statistics, Days in month = 15. Note that it is possible for bed occupancy to be greater than 100% if a patient is admitted and discharge on the same day and another patient is admitted to the same bed on that same day. Bed occupancy (%) is reported to the accuracy of tenths, i.e. 0.1. Source - https://gateway.euro.who.int/en/indicators/hfa_542-6210-bed-occupancy-rate-acute-care-hospitals-only/.

**Filters**

Facility, Location

**Default date range**: 30days


---

### Imaging requests line list

**Report Description**

This report generates a list of all patients that have had an imaging request created and details of that imaging request for the selected parameters. Patients are listed in chronological order based on the lab request date and time. 

If an imaging request has more than one area to be imaged than the request will be reported across multiple lines. The report includes imaging requests with all statuses and if a request has been cancelled will display the reason for cancellation.  

**Filters**

Facility, Requesting clinician, Status, Imaging type

**Default date range**: 24hours


---

### Imaging requests summary

**Report Description**

This report generates a statistical summary of imaging requests by date, department and imaging type. Each indicator is reported by day. Dates are listed chronologically by department and imaging type. Imaging requests with a status of cancelled, deleted or entered in error are excluded from this report. 

Details on how each indicator is calculated are provided below:
- Total new requests = The number of imaging requests generated on the specified day. 
- Total requests with a status of pending = The number of imaging requests with a status of pending. This number may include requests generated on a different date. 
- Total requests completed = The number of imaging requests with status updated to completed on the specified day. 

**Filters**

Facility, Department, Imaging type

**Default date range**: 30days


---

### Incomplete referrals

**Report Description**

This report lists all patients that have a pending referral for the selected parameters.

**Filters**

Village, Doctor/Nurse

**Default date range**: allTime


---

### Invoicing insurance remaining balance line list

**Report Description**

This report generates a list of all invoices with outstanding insurer balances. Each row represents a single invoice-insurer combination showing the amount covered by each insurer, payments received, and remaining balance. The report includes patient details, invoice information, and insurer-specific payment status. Results are ordered chronologically by discharge date.

**Filters**

Insurer

**Default date range**: allTime


---

### Invoicing patient payment by discharge location summary

**Report Description**

This report generates a summary of patient payments by discharge location. Each row in the report represents a single discharge location. The report includes location and payment information. Locations are listed in alphabetical order.

**Filters**

Facility, Discharging Area

**Default date range**: allTime


---

### Invoicing patient remaining balance line list

**Report Description**

This report generates a list of all patients that have a remaining balance. Each row in the report represents a single patient with a remaining balance. The report includes patient and remaining balance information. Patients are listed in chronological order by discharge date.

**Default date range**: allTime


---

### Invoicing payment methods line list

**Report Description**

This report generates a list of all patient payments. Each row in the report represents a single payment. The report includes patient, payment and payment method information. Payments are listed in chronological order by payment date.

**Filters**

Payment method

**Default date range**: allTime


---

### Invoicing pending line list

**Report Description**

Pending Invoicing Line List. This report generates a list of all encounters that have not been invoiced.

**Default date range**: allTime


---

### Invoicing summary

**Report Description**

This report generates a summary of invoices. The report includes patient, insurer and remaining balance information. Patients are listed in chronological order by discharge date.

**Default date range**: allTime


---

### Lab requests line list

**Report Description**

This report generates a list of all patients that have had a lab request created and details of the request for the selected parameters. Patients are listed in chronological order based on the lab request date and time.  

The report includes lab requests for all statuses and if a request has been cancelled will display the reason for cancellation. 

**Filters**

Requesting clinician, Test category, Status

**Default date range**: 7days


---

### Lab requests summary

**Report Description**

This report provides a statistical summary of lab requests by date, department and lab test category.

**Filters**

Facility, Department, Category

**Default date range**: allTime


---

### Lab tests line list

**Report Description**

This report generates a list of all patients that have had a lab test created. Patients are listed in chronological order based on the lab request date and time.

**Filters**

Status, Test category

**Default date range**: 7days


---

### Location bookings line list

**Report Description**

This report generates a list of all location bookings for the selected parameters. Patients are listed in chronological order by date and time of booking

**Filters**

Facility, Area, Clinician, Booking type, Status

**Default date range**: next30days


---

### Ongoing conditions line list

**Report Description**

This report lists all patients with ongoing conditions for the selected parameters.

**Default date range**: 7days


---

### Outpatient appointments line list

**Report Description**

This report generates a list of all patients with a scheduled appointment for the selected parameters. Patients are listed in chronological order by date and time of scheduled appointment

**Filters**

Facility, Area, Clinician, Appointment type, Status

**Default date range**: next30days


---

### Patient details edits line list

**Report Description**

This report lists all of the users that have edited the selected patient's personal details for the selected date range and when the edits were made. Edits are listed in chronological order.

**Filters**

Patient, User

**Default date range**: 24hours


---

### Patient views line list

**Report Description**

This report lists all of the users that have viewed the selected patient's record for the selected date range and when the view occurred. A patient 'view' is defined as a single access to a patient record where a patient record can be accessed from a patient listing table such as the 'All patients' table, the 'Active lab requests' table, or the 'Immunisation register'. A patient record can also be accessed via features such as the 'Recently viewed patients' and the scheduling module. Each individual access by a user will create a new row within the report. Views are listed in chronological order for the selected date range.

**Filters**

Patient, User

**Default date range**: 24hours


---

### Procedures line list

**Report Description**

This report pulls list of all patients that have documented procedures during the selected date period 

**Filters**

Facility, Procedure clinician, Department, Area, Location

**Default date range**: 24hours


---

### Program registry line list

**Report Description**

This report generates the same data that appears on the Registry page. This report will include all people registered within the date range selected in order of the newest (most recent) registration to the oldest. Any patients removed from the register should not be included in this report (see another report called Program Registry Removed Patients).
Home village: Per patient details
Currently in: Can be village or facility, depends how the register is confugured. Will only be completed if a form associated with the register includes this field.
Related conditions: Lists all related conditions associated with the patient and the register they are on (conditions listed at the time of report generation, any conditions removed previously are not included)
Status: Current status of the patient per the 'status' function within the register.
Date of registration: Date the patient was added to this registry. If patient has been added to this registry more than once (i.e. added, removed, added again), the date listed is the date of the current addition to the register.
Registered by: Name of Tamanu user who added the patient to this registry
Registering facility: Facility selected when patient is first added to the registry

**Filters**

Registry

**Default date range**: allTime


---

### Recent diagnoses line list

**Report Description**

This report lists all patients that have had the specified diagnosis/es recorded.

**Filters**

Facility, Village, Diagnosis, Diagnosis 2, Diagnosis 3, Diagnosis 4, Diagnosis 5, Clinician

**Default date range**: 24hours


---

### Registered births line list

**Report Description**

This report generates a list of all registered births for the selected parameters. Patients are listed in chronological order by date and time of birth. The report also includes key demographic information and birth details for each patient.

**Filters**

Facility, Village

**Default date range**: 7days


---

### Registered patients by dob line list

**Report Description**

This report generates a list of all patients that have been registered, including date of registration and which user completed the registration. Patients are listed in chronological order by date of administration. The report also includes key demographic information for each patient. 

**Default date range**: 7days


---

### Registered patients daily summary

**Report Description**

This report generates a summary of the number of patients that have been registered by date and sex for the selected date range. 

**Default date range**: allTime


---

### Registered patients line list

**Report Description**

This report generates a list of all patients that have been registered, including date of registration and which user completed the registration. Patients are listed in chronological order by date of administration. The report also includes key demographic information for each patient. 

**Default date range**: 7days


---

### Sensitive lab requests line list

**Report Description**

This report generates a list of all patients that have had a lab request containing sensitive tests created and details of the request for the selected parameters. Patients are listed in chronological order based on the lab request date and time.  

The report includes lab requests for all statuses and if a request has been cancelled will display the reason for cancellation. 

**Filters**

Requesting clinician, Test category, Status

**Default date range**: 7days


---

### Sensitive lab tests line list

**Report Description**

This report generates a list of all patients that have had sensitive lab tests performed for the selected parameters. Patients are listed in chronological order based on the lab request date and time. Only lab tests marked as sensitive in the system are included in this report.

The report includes detailed test results, verification status, and completion information for sensitive tests only.

**Filters**

Status, Test category

**Default date range**: 7days


---

### Upcoming vaccinations line list

**Report Description**

This report generates upcoming vaccination schedules for patients up to 18 years old by default or for patients born within the user-selected date range.

**Filters**

Category, Vaccine, Vaccine status

**Default date range**: 18years


---

### User audit report

**Report Description**

This report generates a summary of user activity for all current and discharged inpatient, emergency and outpatient encounters for the selected date range. Encounters are listed in chronological order by encounter start date and time. 

The following details are included for each encounter:
- User name: The user assigned as the supervising clinician at the time of report generation or at time of discharge  
- Role: The role of the supervising clinician 
- Patient category: Patient billing type
- Triage category: Triage category for the patient if an emergency encounter
- Department: Assigned department at the time of report generation or at time of discharge  
- Area: Assigned area at the time of report generation or at time of discharge  
- Location: Assigned location at the time of report generation or at time of discharge
- Notes start time: The time first note was completed (excludes system generated notes)
- Notes end time: The time the final note was completed (excludes system generated notes)
- Discharges: Specifies whether or not the patient has been discharged
- Non-discharge by clinicians: If patient is automatically discharged, this column will display the name of the clinician who last authored a note or who the note was written on behalf of

**Filters**

Facility, Department, Area

**Default date range**: 24hours


---

### Vaccine audit line list

**Report Description**

This report generates a list of all patients that have a vaccination record deleted or updated from 'Not given' to 'Given'. Patients are listed alphabetically by last name and date of vaccination in chronological order. 

The report includes the following information in addition to the vaccination date and name:
Vaccination status: Where 'Recorded in error' is the status of a deleted record and 'Historical' is the status of a vaccine recorded as 'Not given' that is now recorded as 'Given'
Vaccine recorded by: The username associated with the person logged into Tamanu at the time the vaccine record was originally created
Given by: The healthcare worker that was recorded as administering the now deleted vaccination record 
Record modified by: The username associated with the person logged into Tamanu at the time the vaccine record was deleted
Record modification date: The date the vaccination record was deleted from Tamanu 
 

**Filters**

Facility, Village, Category, Vaccine, Status

**Default date range**: 7days


---

### Vaccine line list

**Report Description**

This report generates a list of all patients that have had a vaccination recorded for the selected parameters. Patients are listed alphabetically by last name and date of vaccination in chronological order. 

The report includes vaccinations with statuses of both 'Given' and 'Not given', and each vaccination recorded is listed on a single row. If a vaccination was initially recorded as 'Not given' and is later marked as 'Given', only the vaccination record with a status of 'Given' will be included in the report.

**Filters**

Facility, Village, Category, Vaccine

**Default date range**: 7days


---

