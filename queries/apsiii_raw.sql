with pa as
(
  select bg.icustay_id, bg.charttime
  , PO2 as PaO2
  , ROW_NUMBER() over (partition by bg.ICUSTAY_ID ORDER BY bg.PO2 DESC) as rn
  from bloodgasfirstdayarterial bg
  left join ventdurations vd
    on bg.icustay_id = vd.icustay_id
    and bg.charttime >= vd.starttime
    and bg.charttime <= vd.endtime
  WHERE vd.icustay_id is null -- is *not* ventilated
  -- and fio2 < 50, or if no fio2, assume room air
  AND coalesce(FIO2, fio2_chartevents, 21) < 50
  AND bg.PO2 IS NOT NULL
)
, aa as
(
  -- join blood gas to ventilation durations to determine if patient was vent
  -- also join to cpap table for the same purpose
  select bg.icustay_id, bg.charttime
  , bg.AADO2
  , ROW_NUMBER() over (partition by bg.ICUSTAY_ID ORDER BY bg.AADO2 DESC) as rn
  -- row number indicating the highest AaDO2
  from bloodgasfirstdayarterial bg
  INNER JOIN ventdurations vd
    on bg.icustay_id = vd.icustay_id
    and bg.charttime >= vd.starttime
    and bg.charttime <= vd.endtime
  WHERE vd.icustay_id is not null -- patient is ventilated
  AND coalesce(FIO2, fio2_chartevents) >= 50
  AND bg.AADO2 IS NOT NULL
)
-- because ph/pco2 rules are an interaction *within* a blood gas, we calculate them here
-- the worse score is then taken for the final calculation
, acidbase as
(
  select bg.icustay_id
  , ph, pco2 as PACO2
  , case
      when ph is null or pco2 is null then null
      when ph < 7.20 then
        case
          when pco2 < 50 then 12
          else 4
        end
      when ph < 7.30 then
        case
          when pco2 < 30 then 9
          when pco2 < 40 then 6
          when pco2 < 50 then 3
          else 2
        end
      when ph < 7.35 then
        case
          when pco2 < 30 then 9
          when pco2 < 45 then 0
          else 1
        end
      when ph < 7.45 then
        case
          when pco2 < 30 then 5
          when pco2 < 45 then 0
          else 1
        end
      when ph < 7.50 then
        case
          when pco2 < 30 then 5
          when pco2 < 35 then 0
          when pco2 < 45 then 2
          else 12
        end
      when ph < 7.60 then
        case
          when pco2 < 40 then 3
          else 12
        end
      else -- ph >= 7.60
        case
          when pco2 < 25 then 0
          when pco2 < 40 then 3
          else 12
        end
    end as acidbase_score
  from bloodgasfirstdayarterial bg
  where ph is not null and pco2 is not null
)
, acidbase_max as
(
  select icustay_id, acidbase_score, ph, paco2
    -- create integer which indexes maximum value of score with 1
  , ROW_NUMBER() over (partition by ICUSTAY_ID ORDER BY ACIDBASE_SCORE DESC) as acidbase_rn
  from acidbase
)
-- define acute renal failure (ARF) as:
--  creatinine >=1.5 mg/dl
--  and urine output <410 cc/day
--  and no chronic dialysis
, arf as
(
  select ie.icustay_id
    , case
        when labs.creatinine_max >= 1.5
        and  uo.urineoutput < 410
        -- acute renal failure is only coded if the patient is not on chronic dialysis
        -- we use ICD-9 coding of ESRD as a proxy for chronic dialysis
        and  icd.ckd = 0
          then 1
      else 0 end as arf
  from icustays ie
  left join uofirstday uo
    on ie.icustay_id = uo.icustay_id
  left join labsfirstday labs
    on ie.icustay_id = labs.icustay_id
  left join
  (
    select hadm_id
      , max(case
          -- severe kidney failure requiring use of dialysis
          when icd9_code in  ('5854','5855','5856') then 1
          -- we do not include 5859 as that is sometimes coded for acute-on-chronic ARF
        else 0 end)
      as ckd
    from diagnoses_icd
    group by hadm_id
  ) icd
    on ie.hadm_id = icd.hadm_id
)
, cohort as
(
select ie.subject_id, ie.hadm_id, ie.icustay_id
      , ie.intime
      , ie.outtime

      , vital.heartrate_min
      , vital.heartrate_mean
      , vital.heartrate_max
      , vital.meanbp_min
      , vital.meanbp_mean
      , vital.meanbp_max
      , vital.tempc_min
      , vital.tempc_mean
      , vital.tempc_max
      , vital.resprate_min
      , vital.resprate_mean
      , vital.resprate_max

      , pa.PaO2
      , aa.AaDO2

      , ab.ph
      , ab.paco2
      , ab.acidbase_score

      , labs.hematocrit_min
      , labs.hematocrit_max
      , labs.wbc_min
      , labs.wbc_max
      , labs.creatinine_min
      , labs.creatinine_max
      , labs.bun_min
      , labs.bun_max
      , labs.sodium_min
      , labs.sodium_max
      , labs.albumin_min
      , labs.albumin_max
      , labs.bilirubin_min
      , labs.bilirubin_max

      , case
          when labs.glucose_max is null and vital.glucose_max is null
            then null
          when labs.glucose_max is null or vital.glucose_max > labs.glucose_max
            then vital.glucose_max
          when vital.glucose_max is null or labs.glucose_max > vital.glucose_max
            then labs.glucose_max
          else labs.glucose_max -- if equal, just pick labs
        end as glucose_max

      , case
          when labs.glucose_min is null and vital.glucose_min is null
            then null
          when labs.glucose_min is null or vital.glucose_min < labs.glucose_min
            then vital.glucose_min
          when vital.glucose_min is null or labs.glucose_min < vital.glucose_min
            then labs.glucose_min
          else labs.glucose_min -- if equal, just pick labs
        end as glucose_min

      -- , labs.bicarbonate_min
      -- , labs.bicarbonate_max
      , vent.vent
      , uo.urineoutput
      -- gcs and its components
      , gcs.mingcs
      , gcs.gcsmotor, gcs.gcsverbal,  gcs.gcseyes, gcs.endotrachflag
      -- acute renal failure
      , arf.arf as arf

from icustays ie
inner join admissions adm
  on ie.hadm_id = adm.hadm_id
inner join patients pat
  on ie.subject_id = pat.subject_id

-- join to above views - the row number filters to 1 row per ICUSTAY_ID
left join pa
  on  ie.icustay_id = pa.icustay_id
  and pa.rn = 1
left join aa
  on  ie.icustay_id = aa.icustay_id
  and aa.rn = 1
left join acidbase_max ab
  on  ie.icustay_id = ab.icustay_id
  and ab.acidbase_rn = 1
left join arf
  on ie.icustay_id = arf.icustay_id

-- join to custom tables to get more data....
left join ventfirstday vent
  on ie.icustay_id = vent.icustay_id
left join gcsfirstday gcs
  on ie.icustay_id = gcs.icustay_id
left join vitalsfirstday vital
  on ie.icustay_id = vital.icustay_id
left join uofirstday uo
  on ie.icustay_id = uo.icustay_id
left join labsfirstday labs
  on ie.icustay_id = labs.icustay_id
)
  
select 
cohort.subject_id, cohort.hadm_id, cohort.icustay_id,
heartrate_min,
heartrate_mean,
heartrate_max,
meanbp_min,
meanbp_mean,
meanbp_max,
tempc_min,
tempc_mean,
tempc_max,
resprate_min,
resprate_mean,
resprate_max,
hematocrit_min,
hematocrit_max,
wbc_min,
wbc_max,
creatinine_min,
creatinine_max,
bun_min,
bun_max,
sodium_min,
sodium_max,
albumin_min,
albumin_max,
bilirubin_min,
bilirubin_max,
glucose_min,
glucose_max,
urineoutput,
gcseyes,
gcsverbal,
gcsmotor,
PaO2,
AaDO2
from cohort
