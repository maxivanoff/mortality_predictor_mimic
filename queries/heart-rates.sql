CREATE TABLE mimiciii.heartrates AS
SELECT ce.subject_id, ce.hadm_id, ce.icustay_id, ce.value, ce.charttime, ad.hospital_expire_flag
FROM mimiciii.admissions ad
LEFT JOIN mimiciii.chartevents ce 
ON ad.hadm_id = ce.hadm_id
WHERE ce.itemid = 211 
