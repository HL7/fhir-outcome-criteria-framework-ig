library DepressionIntervention version '0.3'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1'
include MATGlobalCommonFunctions version '5.0.000' called Global
include DepressionOutcomes version '0.4'

codesystem "SNOMEDCT": 'http://snomed.info/sct/731000124108'
codesystem "LOINC": 'http://loinc.org'

context Patient

//Base definition: TriggerCriteria - Diagnosis of active depression
define "TriggerCriteria":
"Depression"
where Depression.clinicalStatus = Global."active"
