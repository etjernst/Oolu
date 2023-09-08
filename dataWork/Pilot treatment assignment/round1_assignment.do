
/****
*
* This do file samples X households for the first round of discount offers
*
* Josh Deutschmann, Sep 2023
*
*****/

global dropbox "~/Dropbox/Collaborations"

global baseline_data "$dropbox/Solar_Data/clean"
global sample_data "$dropbox/Oolu/Data/OPM baseline/Sample"
global output_dir "$dropbox/Oolu/Data/Pilot treatment assignment"


* Seed from random.org [1,1000000000]
set seed 397391868


* First, get list of completed respondents from baseline survey
use "$baseline_data/mainsurvey_complete", clear

keep resp_id

save "$output_dir/baseline_ids", replace

* Next, get other info about sample from sampling file
use "$sample_data/oolu_opm_pilot_sample_extended", clear

drop dup

rename hhid resp_id

merge 1:1 resp_id using "$output_dir/baseline_ids"
assert _m!=2
drop if _m!=3
drop _m

* Unlocked customers have already paid off system, so don't need to keep them
drop if status=="unlocked"

* Sort by ID before randomization
sort resp_id, stable

g double randsort = runiform()
sort status randsort, stable
by status: g rand_order = _n

* Oversample deactivated
g treated_round1 = 0
replace treated_round1 = 1 if rand_order<=20 & status=="deactivated" // oversample deactivated (20/41)
replace treated_round1 = 1 if rand_order<=10 & status=="active"

save "$output_dir/treated_round1_assignment", replace

* Prep excel sheet for Oolu
keep if treated_round1==1
drop survey_sample survey_order extra_replacement_order randsort rand_order treated_round1 original_sample
order account_number status customer_full_name system_type resp_id
export excel using "$output_dir/round1_discount_offers.xlsx", replace first(variables) 
