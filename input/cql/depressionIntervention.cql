library DepressionIntervention version '0.3'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1'
include MATGlobalCommonFunctions version '5.0.000' called Global

codesystem "ConditionClinicalStatusCodes": 'http://terminology.hl7.org/CodeSystem/condition-clinical'
codesystem "SNOMEDCT": 'http://snomed.info/sct/731000124108'
codesystem "LOINC": 'http://loinc.org'

valueset "Depression Condition": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1196.314'
valueset "PHQ-9 Total Score Observation": 'http://cts.nlm.nih.gov/fhir/ValueSet/oid-placeholder-ph9-total-score'
valueset "Major Depression Condition": 'http://cts.nlm.nih.gov/fhir/ValueSet/oid-placeholder-major-depression'
valueset "Dysthmia Condition": 'http://cts.nlm.nih.gov/fhir/ValueSet/oid-placeholder-dysthmia'
valueset "Suicide": 'http://cts.nlm.nih.gov/fhir/ValueSet/oid-placeholder-suicide'
valueset "Expired": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1196.345'

code "Birthdate": '21112-8' from "LOINC" display 'Birth date'

parameter "Measurement Period" Interval<DateTime>
//  default Interval[@2020-01-01T00:00:00.0, @2021-01-01T00:00:00.0)

context Patient

//Base definition: Depression condition
define "Depression":
["Condition": "Depression Condition"] Depression
where Depression.verificationStatus = Global."confirmed"
or Depression.verificationStatus is null


