library DepressionOutcomes version '0.3'

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

define "All-cause Mortality":
["Condition": "Expired"] Expired
where Expired.verificationStatus = Global."confirmed"
or Expired.verificationStatus is null

//Outcome: All-cause mortality (category=survival)
define "Outcome All-cause Mortality":
exists("All-cause Mortality")

//Outcome: 12-mo All-cause mortality (category=survival)
define "Outcome 12mo All-cause Mortality":
exists ("All-cause Mortality" AllCauseMortality
where Global."Normalize Interval"(AllCauseMortality.onset) during "12mo Measurement Window From Start of Measurement Period")

define "12mo Measurement Window From Start of Measurement Period":
Interval[start of "Measurement Period", start of "Measurement Period" + 12 months)

define "Major Depression or Dysthmia":
(["Condition": "Major Depression Condition"]
 union ["Condition": "Dysthmia Condition"]) MajorDepressionOrDysthmia
 where MajorDepressionOrDysthmia.verificationStatus = Global."confirmed"
 or MajorDepressionOrDysthmia.verificationStatus is null

define "Death from Suicide":
["Condition": "Suicide"] SuicideDeath with "Major Depression or Dysthmia" MajorDepressionOrDysthmia
such that (SuicideDeath.verificationStatus = Global."confirmed"
or SuicideDeath.verificationStatus is null) and MajorDepressionOrDysthmia is not null

//Outcome: Death from Suicide (category=survival)
define "Outcome Death from Suicide":
exists("Death from Suicide")

define "12mo Death from Suicide":
"Death from Suicide" SuicideDeath
where Global."Normalize Interval"(SuicideDeath.onset) during "12mo Measurement Window From Start of Measurement Period"

//Outcome: 12-mo Death from Suicide (category=survival)
define "Outcome 12mo Death from Suicide":
exists("12mo Death from Suicide")

//Base definition: PHQ-9 gt 9 observation exists
define "PHQ-9 GT 9 Observation":
["Observation": "PHQ-9 Total Score Observation"] PHQ9_GT9
where PHQ9_GT9.status = 'final'
and PHQ9_GT9.value as Quantity > 9

define "First PHQ-9 GT 9 in Measurement Period":
{First ("PHQ-9 GT 9 Observation" FirstPHQ9_GT9
where Global."Normalize Interval"(FirstPHQ9_GT9.effective) during "Measurement Period")
}

// First PHQ-9 in Period that is >9; >=18, with Depression at time of PHQ-9>9; Major depression onset before PHQ-9>9
define "First PHQ-9 GT 9 Adult with Major Depression or Dysthmia Onset Before":
from
"First PHQ-9 GT 9 in Measurement Period" FirstPHQ9_GT9,
["Patient"] Pt,
"Major Depression or Dysthmia" MajorDepressionOrDysthmia
where Global.CalendarAgeInYearsAt(FHIRHelpers.ToDate(Pt.birthDate), start of Global."Normalize Interval"(FirstPHQ9_GT9.effective)) >= 18
and start of Global."Normalize Interval"(MajorDepressionOrDysthmia.onset) before start of Global."Normalize Interval"(FirstPHQ9_GT9.effective)
return FirstPHQ9_GT9

define "PHQ-9 Observation":
["Observation": "PHQ-9 Total Score Observation"] PHQ9
where PHQ9.status = 'final'

//Most recent PHQ-9 in the 12m Measurement Window (6m +/60d from the first PHQ9 that is > 9 during Measurement Period)
//Question: is it ok to use 4m - 8m, or does it have to be exactly 6m-60d and 6m+60d?
define "Most Recent PHQ-9 in 6m Plus Minus 60d Measurement Window":
Last (
  "PHQ-9 Observation" PHQ9
  with "First PHQ-9 GT 9 Adult with Major Depression or Dysthmia Onset Before" FirstPHQ9_GT9
  such that start of Global."Normalize Interval"(PHQ9.effective) during
  Interval[start of Global."Normalize Interval"(FirstPHQ9_GT9.effective) + 4 months, start of Global."Normalize Interval"(FirstPHQ9_GT9.effective) + 8 months)
  and PHQ9.status = 'final'
  and PHQ9.value is not null
)

//Outcome: 6mo Improvement in Depressive Symptoms - Remission (category=clinical response)
//First PHQ-9 in Measurement Period that is >9; Measure Window is 6mo +/- 60 days; Most recent in window is remission (PHQ-9 < 5)
define "Outcome 6mo Improvement in Depressive Symptoms Remission":
exists({"Most Recent PHQ-9 in 6m Plus Minus 60d Measurement Window" LastPHQ9
where LastPHQ9.value as Quantity < 5})

//Most recent PHQ-9 in the 12m Measurement Window (12m +/60d from the first PHQ9 that is > 9 during Measurement Period)
define "Most Recent PHQ-9 in 12m Plus Minus 60d Measurement Window":
Last (
  "PHQ-9 Observation" PHQ9
  with "First PHQ-9 GT 9 Adult with Major Depression or Dysthmia Onset Before" FirstPHQ9_GT9
  such that start of Global."Normalize Interval"(PHQ9.effective) during
  Interval[start of Global."Normalize Interval"(FirstPHQ9_GT9.effective) + 10 months, start of Global."Normalize Interval"(FirstPHQ9_GT9.effective) + 14 months)
  and PHQ9.status = 'final'
  and PHQ9.value is not null
)

//Outcome: 12mo Improvement in Depressive Symptoms - Remission (category=clinical response)
define "Outcome 12mo Improvement in Depressive Symptoms Remission":
exists({"Most Recent PHQ-9 in 12m Plus Minus 60d Measurement Window" LastPHQ9
where LastPHQ9.value as Quantity < 5})

//Outcome: 6mo Improvement in Depressive Symptoms - Response (category=clinical response)
//Major Depression or Dysthymia condition exists; and PHQ-9 observation demonstrates appropriate change in score
//response to treatment defined as a PHQ-9 score that is reduced by 50% or greater from the initial PHQ-9 score (in the Measurement Window).
define "Outcome 6mo Improvement in Depressive Symptoms Response":
exists(
  from
    "Most Recent PHQ-9 in 6m Plus Minus 60d Measurement Window" LastPHQ9,
    "First PHQ-9 GT 9 Adult with Major Depression or Dysthmia Onset Before" FirstPHQ9_GT9
    where
    (FirstPHQ9_GT9.value - LastPHQ9.value)/FirstPHQ9_GT9.value >= 0.5
)

//Outcome: 12mo Improvement in Depressive Symptoms - Response (category=clinical response)
define "Outcome 12mo Improvement in Depressive Symptoms Response":
exists(
  from
    "Most Recent PHQ-9 in 12m Plus Minus 60d Measurement Window" LastPHQ9,
    "First PHQ-9 GT 9 Adult with Major Depression or Dysthmia Onset Before" FirstPHQ9_GT9
    where
    (FirstPHQ9_GT9.value - LastPHQ9.value)/FirstPHQ9_GT9.value >= 0.5
)

//Outcome: Worsening in Depressive Symptoms- Recurrence (category=clinical response)
/**meets remission criteria:
(remission: First PHQ-9 in Measurement Period that is >9; Measure Window is 6mo +/- 60 days; Most recent in window is remission (PHQ-9 < 5))
meets 6 OR 12m +/- 60d remission criteria  (First PHQ-9 in Period that is >9, Measure Window is 6mo +/- 60 days, Most recent in window is remission (score <5))
)
remission at least 2 months
No evidence of 'recurrence' for at least 2 months
'recurrence'
50% increase in PHQ-9 score; OR
PHQ-9 score > 9; OR
hospitalization for depression or suicidality
Timeframe for recurrence?
Any recurrence 2mo after remission to end of measurement window +60d**/

/**
- Most Recent PHQ-9 in 6m Plus Minus 60d Measurement Window returns the most recent PHQ9 that is LT5
in the 6m (+/- 60d) measurement window from the first PHQ9 that is GT9 during the measurement period
- Most Recent PHQ-9 in 12m Plus Minus 60d Measurement Window returns the most recent PHQ9 that is LT5
in the 12m (+/- 60d) measurement window from the first PHQ9 that is GT9 during the measurement period
- Meeting Remission criteria (6m Remission or 12m Remission):
--"Most Recent PHQ-9 in 6m Plus Minus 60d Measurement Window" is < 5
--"Most Recent PHQ-9 in 12m Plus Minus 60d Measurement Window" is < 5
- No evidence of "recurrence" for at least 2m (the length of the recurrence period)
-- recurrence occurred during 2m after the Remission and before the end of measurement window (12 mo + 60d),
-- recurrence defined as: 50% increase in PHQ9 score, or PHQ-9 > 9, or hospitalization for depression or suicidality
**/

// PHQ9 during the 2m after the date of the PHQ9<5 that meets the 6m remission criteria is also <5, which indicates the patient is in 6m remission.
define "PHQ9 Observation Show 6m Remission":
from
  "Most Recent PHQ-9 in 6m Plus Minus 60d Measurement Window" Last6mPHQ9,
  "PHQ-9 Observation" PHQ9
where Last6mPHQ9.value as Quantity <5
  and start of Global."Normalize Interval"(PHQ9.effective) during Interval[start of Global."Normalize Interval"(Last6mPHQ9.effective), start of Global."Normalize Interval"(Last6mPHQ9.effective) + 2 months)
  and PHQ9.value as Quantity < 5
return PHQ9

// PHQ9 during the 2m after the date of the PHQ9<5 that meets the 12m remission criteria is also <5, which indicates the patient is in 12m remission.
define "PHQ9 Observation Show 12m Remission":
from
  "Most Recent PHQ-9 in 12m Plus Minus 60d Measurement Window" Last12mPHQ9,
  "PHQ-9 Observation" PHQ9
where Last12mPHQ9.value as Quantity < 5
and start of Global."Normalize Interval"(PHQ9.effective) during Interval[start of Global."Normalize Interval"(Last12mPHQ9.effective), start of Global."Normalize Interval"(Last12mPHQ9.effective) + 2 months)
and PHQ9.value as Quantity < 5
return PHQ9

define "Is In 6m Remission":
exists("PHQ9 Observation Show 6m Remission")

define "Is In 12m Remission":
exists("PHQ9 Observation Show 12m Remission")

//Question: since the ending time window is "12m +/- 60d", is it okay to only look for 12m + 60d? the (12m - 60d) would be covered in the 2m to (12+60d) range.
define "Hospitalization 2m after 6m Remission in 12m Plus Minus 60d Measurement Window":
from
    [Encounter: Global."Encounter Inpatient"] EncInpatient,
    "PHQ9 Observation Show 6m Remission" PHQ9Remission6m
where PHQ9Remission6m is not null
    and EncInpatient.status = 'finished'
		and EncInpatient.period during Interval[start of Global."Normalize Interval"(PHQ9Remission6m.effective) + 2 months,
      start of Global."Normalize Interval"(PHQ9Remission6m.effective) + 12 months + 60 days)

define "Hospitalization 2m after 12m Remission in 12m Plus Minus 60d Measurement Window":
from
    [Encounter: Global."Encounter Inpatient"] EncInpatient,
    "PHQ9 Observation Show 12m Remission" PHQ9Remission12m
where PHQ9Remission12m is not null
    and EncInpatient.status = 'finished'
		and EncInpatient.period during Interval[start of Global."Normalize Interval"(PHQ9Remission12m.effective) + 2 months,
      start of Global."Normalize Interval"(PHQ9Remission12m.effective) + 12 months + 60 days)

/**
define "No Evidence Recurrence Hospitalization":
not (exists("Hospitalization 2m after 6m Remission in 12m Plus Minus 60d Measurement Window")
or exists("Hospitalization 2m after 12m Remission in 12m Plus Minus 60d Measurement Window"))
**/

define "No Evidence Recurrence Hospitalization 6m Remission":
not (exists("Hospitalization 2m after 6m Remission in 12m Plus Minus 60d Measurement Window"))

define "No Evidence Recurrence Hospitalization 12m Remission":
not (exists("Hospitalization 2m after 12m Remission in 12m Plus Minus 60d Measurement Window"))

define "PHQ9 50Percent Increase 2m after 6m Remission in 12m Plus Minus 60d Measurement Window":
from
    "PHQ-9 Observation" PHQ9,
    "PHQ9 Observation Show 6m Remission" PHQ9Remission6m
where PHQ9Remission6m is not null
    and (PHQ9.value - PHQ9Remission6m.value)/PHQ9Remission6m.value >= 0.5
		and PHQ9.effective during Interval[start of Global."Normalize Interval"(PHQ9Remission6m.effective) + 2 months,
      start of Global."Normalize Interval"(PHQ9Remission6m.effective) + 12 months + 60 days)

define "PHQ9 50Percent Increase 2m after 12m Remission in 12m Plus Minus 60d Measurement Window":
from
    "PHQ-9 Observation" PHQ9,
    "PHQ9 Observation Show 12m Remission" PHQ9Remission12m
where PHQ9Remission12m is not null
    and (PHQ9.value - PHQ9Remission12m.value)/PHQ9Remission12m.value >= 0.5
		and PHQ9.effective during Interval[start of Global."Normalize Interval"(PHQ9Remission12m.effective) + 2 months,
      start of Global."Normalize Interval"(PHQ9Remission12m.effective) + 12 months + 60 days)

define "No Evidence Recurrence PHQ9 50Percent Increase 6m Remission":
  exists("PHQ9 50Percent Increase 2m after 6m Remission in 12m Plus Minus 60d Measurement Window")

define "No Evidence Recurrence PHQ9 50Percent Increase 12m Remission":
  exists("PHQ9 50Percent Increase 2m after 12m Remission in 12m Plus Minus 60d Measurement Window")

define "PHQ9 GT9 2m after 6m Remission in 12m Plus Minus 60d Measurement Window":
from
    "PHQ-9 Observation" PHQ9,
    "PHQ9 Observation Show 6m Remission" PHQ9Remission6m
where PHQ9Remission6m is not null
    and PHQ9.value > 9
		and PHQ9.effective during Interval[start of Global."Normalize Interval"(PHQ9Remission6m.effective) + 2 months,
      start of Global."Normalize Interval"(PHQ9Remission6m.effective) + 12 months + 60 days)

define "PHQ9 GT9 2m after 12m Remission in 12m Plus Minus 60d Measurement Window":
from
    "PHQ-9 Observation" PHQ9,
    "PHQ9 Observation Show 12m Remission" PHQ9Remission12m
where PHQ9Remission12m is not null
    and PHQ9.value > 9
		and PHQ9.effective during Interval[start of Global."Normalize Interval"(PHQ9Remission12m.effective) + 2 months,
      start of Global."Normalize Interval"(PHQ9Remission12m.effective) + 12 months + 60 days)

define "No Evidence Recurrence PHQ9 GT9 6m Remission":
not (exists("PHQ9 GT9 2m after 6m Remission in 12m Plus Minus 60d Measurement Window"))

define "No Evidence Recurrence PHQ9 GT9 12m Remission":
not (exists("PHQ9 GT9 2m after 12m Remission in 12m Plus Minus 60d Measurement Window"))

define "Outcome Worsening in Depressive Symptoms Recurrence":
("Is In 6m Remission"
and "No Evidence Recurrence Hospitalization 6m Remission"
and "No Evidence Recurrence PHQ9 50Percent Increase 6m Remission"
and "No Evidence Recurrence PHQ9 GT9 6m Remission")
or
("Is In 12m Remission"
and "No Evidence Recurrence Hospitalization 12m Remission"
and "No Evidence Recurrence PHQ9 50Percent Increase 12m Remission"
and "No Evidence Recurrence PHQ9 GT9 12m Remission")

//Outcome: 6mo Worsening in Depressive Symptoms- Recurrence (category=clinical response)
//define "6mo Worsening in Depressive Symptoms- Recurrence":

//Outcome: 12mo Worsening in Depressive Symptoms- Recurrence (category=clinical response)
//define "12mo Worsening in Depressive Symptoms- Recurrence":


//Outcome: Depression-related Adverse Events (category=event of interest)
//define "Depression-related Adverse Events":


//Outcome: Suicide Ideation and Behavior (category=event of interest)
//define "Suicide Ideation and Behavior":


//Outcome: Depression-specific Quality of Life (category=patient reported)
//define "Depression-specific Quality of Life":


//Outcome: Depression-related Resource Utilization (category=resource utilization)
//define "Depression-related Resource Utilization":


//Outcome: Work Productivity (category=resource utilization)
//define "Work Productivity":
