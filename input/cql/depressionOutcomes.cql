library DepressionOutcomes version '0.4'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers
include MATGlobalCommonFunctions version '5.0.000' called Global

codesystem "ConditionClinicalStatusCodes": 'http://terminology.hl7.org/CodeSystem/condition-clinical'
codesystem "SNOMEDCT": 'http://snomed.info/sct/731000124108'
codesystem "LOINC": 'http://loinc.org'
codesystem "NCI": 'http://ncimeta.nci.nih.gov'

valueset "Depression Condition": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1196.314'
valueset "Dysthmia Condition": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.67.1.101.1.254'
valueset "Expired": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1196.345'
valueset "Depression Medications": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1196.350'
valueset "Suicidality": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1196.353'

// This value set is Suicide Event, the resource uses Condition
valueset "Suicide": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1196.349'

//No Elimu value set. Is this NCQA value set ok?
valueset "Major Depression Condition": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.105.12.1007'

valueset "Suicide Ideation and Behavior Answer List": 'http://cts.nlm.nih.gov/fhir/ValueSet/suicide_ideation_behavior_answer_list_place_holder'

code "Birthdate": '21112-8' from "LOINC" display 'Birth date'
code "Suicide Ideation and Behavior": '44260-8' from "LOINC" display 'Thoughts that you would be better off dead, or of hurting yourself in some way in last 2W'
code "PHQ-9 Total Score Observation": '44261-6' from "LOINC" display 'Patient Health Questionnaire 9 item (PHQ-9) total score [Reported]'
code "Q-LES-Q": 'Q-LES-Q' from "NCI" display 'Quality Of Life Enjoyment And Satisfaction Questionnaire'

code "Several days": 'LA6569-3' from "LOINC" display 'Several days'
code "More than half the days": 'LA6570-1' from "LOINC" display 'More than half the days'
code "Nearly every day": 'LA6571-9' from "LOINC" display 'Nearly every day'

code "WPAI Item 5": 'WPAI Item 5' //no code system

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

define "12mo Measurement Window From Start of Measurement Period":
Interval[start of "Measurement Period", start of "Measurement Period" + 12 months)

//Outcome: All-cause mortality (category=survival)
define "Outcome All-cause Mortality":
exists("All-cause Mortality")

//Outcome: 12-mo All-cause mortality (category=survival)
define "Outcome 12mo All-cause Mortality":
exists ("All-cause Mortality" AllCauseMortality
where Global."Normalize Interval"(AllCauseMortality.onset) during "12mo Measurement Window From Start of Measurement Period"
//-----------------------------------------------------------

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
//-----------------------------------------------------------

define "PHQ-9 Observation":
["Observation": "PHQ-9 Total Score Observation"] PHQ9
where PHQ9.status = 'final'

define "PHQ-9 GT 9 Observation":
"PHQ-9 Observation" PHQ9
where PHQ9.value as Quantity > 9

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

//Most recent PHQ-9 in the 6m Measurement Window (6m +/60d from the first PHQ9 that is > 9 during Measurement Period)
//note: used 6m +/- 60 days rather than 4 mo and 8 mo
define "Most Recent PHQ-9 in 6m Plus Minus 60d Measurement Window":
Last (
  "PHQ-9 Observation" PHQ9
  with "First PHQ-9 GT 9 Adult with Major Depression or Dysthmia Onset Before" FirstPHQ9_GT9
  such that start of Global."Normalize Interval"(PHQ9.effective) during
  Interval[start of Global."Normalize Interval"(FirstPHQ9_GT9.effective) + 6 months - 60 days, start of Global."Normalize Interval"(FirstPHQ9_GT9.effective) + 6 months + 60 days)
  and PHQ9.status = 'final'
  and PHQ9.value is not null
)

//Most recent PHQ-9 in the 12m Measurement Window (12m +/60d from the first PHQ9 that is > 9 during Measurement Period)
//note: used 12m +/- 60 days rather than 10 mo and 14 mo
define "Most Recent PHQ-9 in 12m Plus Minus 60d Measurement Window":
Last (
  "PHQ-9 Observation" PHQ9
  with "First PHQ-9 GT 9 Adult with Major Depression or Dysthmia Onset Before" FirstPHQ9_GT9
  such that start of Global."Normalize Interval"(PHQ9.effective) during
  Interval[start of Global."Normalize Interval"(FirstPHQ9_GT9.effective) + 12 months - 60 days, start of Global."Normalize Interval"(FirstPHQ9_GT9.effective) + 12 months + 60 days)
  and PHQ9.status = 'final'
  and PHQ9.value is not null
)

//Outcome: 6mo Improvement in Depressive Symptoms - Remission
//First PHQ-9 in Measurement Period that is >9; Measure Window is 6mo +/- 60 days; Most recent in window is remission (PHQ-9 < 5)
define "Outcome 6mo Improvement in Depressive Symptoms Remission":
exists({"Most Recent PHQ-9 in 6m Plus Minus 60d Measurement Window" LastPHQ9
where LastPHQ9.value as Quantity < 5})

//Outcome: 12mo Improvement in Depressive Symptoms - Remission
define "Outcome 12mo Improvement in Depressive Symptoms Remission":
exists({"Most Recent PHQ-9 in 12m Plus Minus 60d Measurement Window" LastPHQ9
where LastPHQ9.value as Quantity < 5})
//-----------------------------------------------------------

//Outcome: 6mo Improvement in Depressive Symptoms - Response
//Major Depression or Dysthymia condition exists; and PHQ-9 observation demonstrates appropriate change in score
//response to treatment defined as a PHQ-9 score that is reduced by 50% or greater from the initial PHQ-9 score (in the Measurement Window).
//First PHQ-9 in Measurement Period that is >9 (where patient is >=18 with major depression or dysthymia)
//Response: f/u PHQ-9 decreases by 50% or more (within 6mo, 12mo, or other specified time window from first PHQ-9>9)
define "Outcome 6mo Improvement in Depressive Symptoms Response":
exists(
  from
    "Most Recent PHQ-9 in 6m Plus Minus 60d Measurement Window" LastPHQ9,
    "First PHQ-9 GT 9 Adult with Major Depression or Dysthmia Onset Before" FirstPHQ9_GT9
    where
    (FirstPHQ9_GT9.value - LastPHQ9.value)/FirstPHQ9_GT9.value >= 0.5
)

//Outcome: 12mo Improvement in Depressive Symptoms - Response
define "Outcome 12mo Improvement in Depressive Symptoms Response":
exists(
  from
    "Most Recent PHQ-9 in 12m Plus Minus 60d Measurement Window" LastPHQ9,
    "First PHQ-9 GT 9 Adult with Major Depression or Dysthmia Onset Before" FirstPHQ9_GT9
    where
    (FirstPHQ9_GT9.value - LastPHQ9.value)/FirstPHQ9_GT9.value >= 0.5
)
//-----------------------------------------------------------

//Outcome: (6mo) (12mo) Improvement in Depressive Symptoms - Recurrence:
//meets 6mo or 12mo +/- 60d remission criteria
//remission at least 2 months: No evidence of 'recurrence' for at least 2 months
//'recurrence': 50% increase in PHQ-9 score; OR PHQ-9 score > 9; OR hospitalization for depression or suicidality
//Timeframe for recurrence? Any recurrence 2mo after remission to end of measurement window +60d (i.e. from 2mo after remission to ~14mo)

// Meets 6m remission criteria: PHQ9 during the 2m after the date of the PHQ9<5 that meets the 6m remission criteria is also <5, which indicates the patient is in 6m remission.
define "PHQ9 Observation Show 6m Remission":
from
  "Most Recent PHQ-9 in 6m Plus Minus 60d Measurement Window" Last6mPHQ9,
  "PHQ-9 Observation" PHQ9
where Last6mPHQ9.value as Quantity <5
  and start of Global."Normalize Interval"(PHQ9.effective) during Interval[start of Global."Normalize Interval"(Last6mPHQ9.effective), start of Global."Normalize Interval"(Last6mPHQ9.effective) + 2 months)
  and PHQ9.value as Quantity < 5
return PHQ9

// Meets 12m remission criteria: PHQ9 during the 2m after the date of the PHQ9<5 that meets the 12m remission criteria is also <5, which indicates the patient is in 12m remission.
define "PHQ9 Observation Show 12m Remission":
from
  "Most Recent PHQ-9 in 12m Plus Minus 60d Measurement Window" Last12mPHQ9,
  "PHQ-9 Observation" PHQ9
where Last12mPHQ9.value as Quantity < 5
and start of Global."Normalize Interval"(PHQ9.effective) during Interval[start of Global."Normalize Interval"(Last12mPHQ9.effective), start of Global."Normalize Interval"(Last12mPHQ9.effective) + 2 months)
and PHQ9.value as Quantity < 5
return PHQ9

//Meets 'recurrence': hospitalization for depression or suicidality after 6m remission (Timeframe: Any recurrence 2mo after remission to end of measurement window +60d (i.e. from 2mo after remission to ~14mo))
//note: the ending time window is "12m +/- 60d", (12m - 60d) would be covered in the 2m to (12+60d) range.
define "Hospitalization 2m after 6m Remission in 12m Plus Minus 60d Measurement Window":
from
    [Encounter: Global."Encounter Inpatient"] EncInpatient,
    "PHQ9 Observation Show 6m Remission" PHQ9Remission6m
where PHQ9Remission6m is not null
    and EncInpatient.status = 'finished'
    and (EncInpatient.reasonCode in "Suicidality" or EncInpatient.reasonCode in "Depression Condition")
    and EncInpatient.period during Interval[start of Global."Normalize Interval"(PHQ9Remission6m.effective) + 2 months,
      start of Global."Normalize Interval"(PHQ9Remission6m.effective) + 12 months + 60 days)

//Meets 'recurrence': hospitalization for depression or suicidality after 12m remission (Timeframe: Any recurrence 2mo after remission to end of measurement window +60d (i.e. from 2mo after remission to ~14mo))
define "Hospitalization 2m after 12m Remission in 12m Plus Minus 60d Measurement Window":
from
    [Encounter: Global."Encounter Inpatient"] EncInpatient,
    "PHQ9 Observation Show 12m Remission" PHQ9Remission12m
where PHQ9Remission12m is not null
    and EncInpatient.status = 'finished'
    and (EncInpatient.reasonCode in "Suicidality" or EncInpatient.reasonCode in "Depression Condition")
		and EncInpatient.period during Interval[start of Global."Normalize Interval"(PHQ9Remission12m.effective) + 2 months,
      start of Global."Normalize Interval"(PHQ9Remission12m.effective) + 12 months + 60 days)

//Meets 'recurrence': 50% increase in PHQ-9 score after 6m remission (Timeframe: Any recurrence 2mo after remission to end of measurement window +60d (i.e. from 2mo after remission to ~14mo))
define "PHQ9 50Percent Increase 2m after 6m Remission in 12m Plus Minus 60d Measurement Window":
from
    "PHQ-9 Observation" PHQ9,
    "PHQ9 Observation Show 6m Remission" PHQ9Remission6m
where PHQ9Remission6m is not null
    and (PHQ9.value - PHQ9Remission6m.value)/PHQ9Remission6m.value >= 0.5
		and Global."Normalize Interval"(PHQ9.effective) during Interval[start of Global."Normalize Interval"(PHQ9Remission6m.effective) + 2 months,
      start of Global."Normalize Interval"(PHQ9Remission6m.effective) + 12 months + 60 days)

//Meets 'recurrence': 50% increase in PHQ-9 score after 12m remission (Timeframe: Any recurrence 2mo after remission to end of measurement window +60d (i.e. from 2mo after remission to ~14mo))
define "PHQ9 50Percent Increase 2m after 12m Remission in 12m Plus Minus 60d Measurement Window":
from
    "PHQ-9 Observation" PHQ9,
    "PHQ9 Observation Show 12m Remission" PHQ9Remission12m
where PHQ9Remission12m is not null
    and (PHQ9.value - PHQ9Remission12m.value)/PHQ9Remission12m.value >= 0.5
		and Global."Normalize Interval"(PHQ9.effective) during Interval[start of Global."Normalize Interval"(PHQ9Remission12m.effective) + 2 months,
      start of Global."Normalize Interval"(PHQ9Remission12m.effective) + 12 months + 60 days)

//Meets 'recurrence': PHQ-9 score >9 after 12m remission (Timeframe: Any recurrence 2mo after remission to end of measurement window +60d (i.e. from 2mo after remission to ~14mo))
define "PHQ9 GT9 2m after 6m Remission in 12m Plus Minus 60d Measurement Window":
from
    "PHQ-9 Observation" PHQ9,
    "PHQ9 Observation Show 6m Remission" PHQ9Remission6m
where PHQ9Remission6m is not null
    and PHQ9.value > 9
		and Global."Normalize Interval"(PHQ9.effective) during Interval[start of Global."Normalize Interval"(PHQ9Remission6m.effective) + 2 months,
      start of Global."Normalize Interval"(PHQ9Remission6m.effective) + 12 months + 60 days)

//Meets 'recurrence': PHQ-9 score >9 after 12m remission (Timeframe: Any recurrence 2mo after remission to end of measurement window +60d (i.e. from 2mo after remission to ~14mo))
define "PHQ9 GT9 2m after 12m Remission in 12m Plus Minus 60d Measurement Window":
from
    "PHQ-9 Observation" PHQ9,
    "PHQ9 Observation Show 12m Remission" PHQ9Remission12m
where PHQ9Remission12m is not null
    and PHQ9.value > 9
		and Global."Normalize Interval"(PHQ9.effective) during Interval[start of Global."Normalize Interval"(PHQ9Remission12m.effective) + 2 months,
      start of Global."Normalize Interval"(PHQ9Remission12m.effective) + 12 months + 60 days)

define "Outcome 6mo Plus Minus 60d Recurrence":
exists("PHQ9 Observation Show 6m Remission")
and (
  exists("Hospitalization 2m after 6m Remission in 12m Plus Minus 60d Measurement Window")
  or exists("PHQ9 50Percent Increase 2m after 6m Remission in 12m Plus Minus 60d Measurement Window")
  or exists("PHQ9 GT9 2m after 6m Remission in 12m Plus Minus 60d Measurement Window")
)

define "Outcome 12mo Plus Minus 60d Recurrence":
exists("PHQ9 Observation Show 12m Remission")
and (
  exists("Hospitalization 2m after 12m Remission in 12m Plus Minus 60d Measurement Window")
  or exists("PHQ9 50Percent Increase 2m after 12m Remission in 12m Plus Minus 60d Measurement Window")
  or exists("PHQ9 GT9 2m after 12m Remission in 12m Plus Minus 60d Measurement Window")
)
//-----------------------------------------------------------

//Outcome: Depression-related Adverse Events (category=event of interest)
// - "Depression"(onset < start of measurement period; abatement > start of measurement period or null); and
// AdverseEvent(actuality is 'actual'; suspectEntity.instance.medication.code in "Depression Medications")
// primaryCodePath in fhir-modelinfo-4.0.1.xml is event.
// note: question for QI-Core, should the primary code be suspectEntity
define "Depression-related Adverse Events":
[AdverseEvent: "Depression Medications"] DepressionRelatedAE
  where DepressionRelatedAE.actuality = 'actual'
  and DepressionRelatedAE.suspectEntity in "Depression Medications"

define "Outcome Depression-related Adverse Events":
"Depression-related Adverse Events" DepressionRelatedAE
with "Depression" DepressionCondition
where Global."Normalize Interval"(DepressionCondition.onset) starts before start of "Measurement Period"
  and (Global."Normalize abatement"(DepressionCondition) starts after start of DepressionCondition.onset or
  Global."Normalize abatement"(DepressionCondition) is null)
and DepressionRelatedAE.date during "Measurement Period"

//Outcome: "12mo Depression treatment-related Adverse Events"
//"Depression treatment-related Adverse Events" during Interval(start of "Measurement Period", start of "Measurement Period" + 12 months)
define "Outcome 12mo Depression-related Adverse Events":
"Depression-related Adverse Events" DepressionRelatedAE
with "Depression" DepressionCondition
where Global."Normalize Interval"(DepressionCondition.onset) starts before start of "Measurement Period"
  and (Global."Normalize abatement"(DepressionCondition) starts after start of DepressionCondition.onset or
  Global."Normalize abatement"(DepressionCondition) is null)
and DepressionRelatedAE.date during "12mo Measurement Window From Start of Measurement Period"
//-----------------------------------------------------------

//Outcome: "Suicide Ideation and Behavior":
//  - observation(code is https://loinc.org/44260-8/; status in [preliminary, final, amended, corrected]; valueCodeableConcept: in [LA6569-3; LA6570-1; LA6571-9])
define "Suicide Ideation and Behavior":
[Observation: "Suicide Ideation and Behavior"] SuicideIdeation
where SuicideIdeation.status in {'preliminary', 'final', 'amended', 'corrected'}
and SuicideIdeation.value in "Suicide Ideation and Behavior Answer List"
//and (SuicideIdeation.value = "Several days" or SuicideIdeation.value = "More than half the days" or SuicideIdeation.value = "Nearly every day")

define "Outcome Suicide Ideation and Behavior":
"Suicide Ideation and Behavior" SuicideIdeation
where Global."Normalize Interval"(SuicideIdeation.effective) during "Measurement Period"

//Outcome: "12mo Suicide Ideation and Behavior":
//  - "Suicide Ideation and Behavior" during Interval(start of "Measurement Period", start of "Measurement Period" + 12 months)
define "Outcome 12mo Suicide Ideation and Behavior":
"Suicide Ideation and Behavior" SuicideIdeation
where Global."Normalize Interval"(SuicideIdeation.effective) during "12mo Measurement Window From Start of Measurement Period"
//-----------------------------------------------------------

//Outcome: "Depression-specific Quality of Life Improvement":
//  - observation1 = first observation(code is 'Q-LES-Q'; status in [preliminary, final, amended, corrected]) in "Measurement Period";
//  - observation2 = last observation(code is 'Q-LES-Q'; status in [preliminary, final, amended, corrected]) in "Measurement Period";
//  - TRUE if observation2.valueQuantity > observation1.valueQuantity
define "Quality of Life Enjoyment and Satisfaction Questionaire":
[Observation: "Q-LES-Q"] Q-LES-Q
where Q-LES-Q.status in {'preliminary', 'final', 'amended', 'corrected'}
and Global."Normalize Interval"(Q-LES-Q.effective) during "Measurement Period"

define "First Q-LES-Q":
First("Quality of Life Enjoyment and Satisfaction Questionaire")

define "Last Q-LES-Q":
Last("Quality of Life Enjoyment and Satisfaction Questionaire")

define "Outcome Depression Specific Quality of Life Improvement":
from
  "First Q-LES-Q" First_Q-LES-Q,
  "Last Q-LES-Q" Last_Q-LES-Q,
where
  First_Q-LES-Q is not null
  and Last_Q-LES-Q is not null
  and Last_Q-LES-Q.valueQuantity > First_Q-LES-Q.valueQuantity
return true

//Outcome: "12mo Depression-specific Quality of Life Improvement":
//  - "Depression-specific Quality of Life Improvement" during Interval(start of "Measurement Period", start of "Measurement Period" + 12 months)
define "12mo Quality of Life Enjoyment and Satisfaction Questionaire":
[Observation: "Q-LES-Q"] Q-LES-Q
where Q-LES-Q.status in {'preliminary', 'final', 'amended', 'corrected'}
and Global."Normalize Interval"(Q-LES-Q.effective) during "12mo Measurement Window From Start of Measurement Period"

define "12mo First Q-LES-Q":
First("Quality of Life Enjoyment and Satisfaction Questionaire")

define "12mo Last Q-LES-Q":
Last("Quality of Life Enjoyment and Satisfaction Questionaire")

define "Outcome 12mo Depression Specific Quality of Life Improvement":
from
  "12mo First Q-LES-Q" First_Q-LES-Q_12mo,
  "12mo Last Q-LES-Q" Last_Q-LES-Q_12mo,
where
  First_Q-LES-Q_12mo is not null
  and Last_Q-LES-Q_12mo is not null
  and Last_Q-LES-Q_12mo.valueQuantity > First_Q-LES-Q_12mo.valueQuantity
return true
//-----------------------------------------------------------

//Outcome: "Depression-related Resource Utilization":
// - Return all claims where claim(status is 'active'; use is 'claim'; diagnosis.diagnosisCodeableConcept in "Depression Condition");
define "Outcome Depression-related Resource Utilization":
[Claim] DepressionRelatedClaim //note: needs to find out if Claim is supported and which element is the primary code
where DepressionRelatedClaim.status = 'active'
and DepressionRelatedClaim.use = 'claim'
and DepressionRelatedClaim.diagnosis.diagnosisCodeableConcept in "Depression Condition"
and DepressionRelatedClaim.created during "Measurement Period"

//Outcome: "12mo Depression-related Resource Utilization":
// - Return all "Depression-related Resource Utilization" claims during Interval(start of "Measurement Period", start of "Measurement Period" + 12 months)
define "Outcome 12mo Depression-related Resource Utilization":
[Claim] DepressionRelatedClaim //note: needs to find out if Claim is supported and which element is the primary code
where DepressionRelatedClaim.status = 'active'
and DepressionRelatedClaim.use = 'claim'
and DepressionRelatedClaim.diagnosis.diagnosisCodeableConcept in "Depression Condition"
and DepressionRelatedClaim.created during "12mo Measurement Window From Start of Measurement Period"
//-----------------------------------------------------------

//Outcome: "Work Productivity Improvement":
//  - observation1 = first observation(code is 'WPAI Item 5'; status in [preliminary, final, amended, corrected]) in "Measurement Period";
//  - observation2 = last observation(code is 'WPAI Item 5'; status in [preliminary, final, amended, corrected]) in "Measurement Period";
//  - TRUE if observation2.valueQuantity < observation1.valueQuantity
define "Work Productivity":
[Observation: "WPAI Item 5"] WPAI //note: the code "WPAI Item 5" is missing code system
where WPAI.status in {'preliminary', 'final', 'amended', 'corrected'}
and Global."Normalize Interval"(WPAI.effective) during "Measurement Period"

define "First WPAI Item 5":
First ("Work Productivity")

define "Last WPAI Item 5":
Last ("Work Productivity")

define "Outcome Work Productivity Improvement":
from
  "First WPAI Item 5" First_WPAI,
  "Last WPAI Item 5" Last_WPAI,
where
  First_WPAI is not null
  and Last_WPAI is not null
  and Last_WPAI.valueQuantity > First_WPAI.valueQuantity
return true

//Outcome: "12mo Work Productivity Improvement":
// - "Work Productivity Improvement" during Interval(start of "Measurement Period", start of "Measurement Period" + 12 months)
define "12mo Work Productivity":
[Observation: "WPAI Item 5"] WPAI
where WPAI.status in {'preliminary', 'final', 'amended', 'corrected'}
and Global."Normalize Interval"(WPAI.effective) during "Measurement Period"

define "12mo First WPAI Item 5":
First ("Work Productivity")

define "12mo Last WPAI Item 5":
Last ("Work Productivity")

define "Outcome 12mo Work Productivity Improvement":
from
  "12mo First WPAI Item 5" First_WPAI_12mo,
  "12mo Last WPAI Item 5" Last_WPAI_12mo,
where
  First_WPAI_12mo is not null
  and Last_WPAI_12mo is not null
  and Last_WPAI_12mo.valueQuantity > First_WPAI_12mo.valueQuantity
return true
