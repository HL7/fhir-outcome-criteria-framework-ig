library DepressionMeasure version '0.3'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1'
include MATGlobalCommonFunctions version '5.0.000' called Global
include DepressionOutcomes version '0.4'

parameter "Measurement Period" Interval<DateTime>
//  default Interval[@2020-01-01T00:00:00.0, @2021-01-01T00:00:00.0)

context Patient

//Base definition: DenominatorCriteria - Active depression during measurement period
define "DenominatorCriteria":
"Depression"
where Depression.clinicalStatus = Global."active" during "Measurement Period"
