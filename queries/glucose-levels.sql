CREATE TABLE mimiciii.glucoselevels AS
SELECT ce.subject_id, ce.hadm_id, ce.icustay_id, ce.itemid, ce.value, ce.charttime, ad.hospital_expire_flag
FROM mimiciii.admissions ad
LEFT JOIN mimiciii.chartevents ce 
ON ad.hadm_id = ce.hadm_id
WHERE ce.itemid IN
(
  807,--	Fingerstick Glucose
  811,--	Glucose (70-105)
  1529,--	Glucose
  3745,--	BloodGlucose
  3744,--	Blood Glucose
  225664,--	Glucose finger stick
  220621,--	Glucose (serum)
  226537--	Glucose (whole blood)
);
