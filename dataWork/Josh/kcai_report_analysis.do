

cd "~/Dropbox/Collaborations/Solar_Data/Data"

use "01_baseline/02_clean/bsl_phone_survey_main", clear

keep if sample_neighbour==0

keep resp_id b06 b07 b07a b08 b09 b17_total b17_val_total

save  "01_baseline/03_working/temp_baseline", replace

use "02_round1/03_working/round1_phone_survey_main", clear

keep resp_id b4 b5 total_fuel total_fuel_val

rename b* r1_b*
rename total_* r1_total_*

save "02_round1/03_working/temp_r1", replace

use "03_round2/03_working/round2_phone_survey_main", clear

keep resp_id b4 b5 total_fuel total_fuel_val

rename b* r2_b*
rename total_* r2_total_*

save "03_round2/03_working/temp_r2", replace

use "01_baseline/03_working/temp_baseline", clear

merge 1:1 resp_id using "02_round1/03_working/temp_r1"
g round1_phonesurvey = _m==3
drop _m

merge 1:1 resp_id using "03_round2/03_working/temp_r2"
g round2_phonesurvey = _m==3
drop _m

* This is the full set that was initially sampled for treatment
g r1_trt_full = inlist(resp_id,1013,4157,4028,1098,1095,1069,4021,1099,1062,1087,5017,2074,2067,2014,2036,5057,2024,2077,5048,2004,2026,2015,2070,5010,2043,2006,2076,2008,2033,2080)
* This is the subset that was actually inactive at time of assignment
g r1_trt_deactivated = inlist(resp_id,5017,2067,2014,2036,5057,2024,2077,5048,2026,2015,5010,2043,2076,2008,2033)
* This is the set of people who received codes, including both currently deactivated and currently active customers
g r1_trt_receivedcode = inlist(resp_id,1013,4028,1098,1095,1099,2074,2014,2036,2077,5010,2043,2006,2008,2033,2080)

g r2_trt_full = inlist(resp_id,4113,4122,1123,1113,1012,4166,1014,1065,1052,1081,2011,2003,5052,2054,2082,2041,2039,2028,5002,2059,2075,2071,2069,2051,2007,5020,2056,2034,2037,2021)
g r2_trt_deactivated = inlist(resp_id,4113,4122,1113,4166,5052,2082,2028,5002,2075,2071,2069,2051,5020,2056,2034,2037)
g r2_trt_receivedcode = inlist(resp_id,4122,1123,1014,1052,2003,2082,2028,5002,2069,2034)


g r2_fuel_zero = r2_total_fuel==0 if round2_phonesurvey==1
reg r2_fuel_zero r2_trt_receivedcode b17_total b09

g r1_fuel_zero = r1_total_fuel==0 if round1_phonesurvey==1
reg r1_fuel_zero r1_trt_receivedcode b17_total b09

reg r2_total_fuel r2_trt_full b17_total b09
reg r1_total_fuel r1_trt_full b17_total b09

reg r2_total_fuel_val r2_trt_full b17_total b09
reg r1_total_fuel_val r1_trt_full b17_total b09

reg r2_b4 r2_trt_full b06 b09
reg r1_b4 r1_trt_full b06 b09

reg r2_b4 r2_trt_receivedcode b06 b09
reg r1_b4 r1_trt_receivedcode b06 b09
