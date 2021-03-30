

cd "D:\Dropbox\Research\Solar\Oolu Data\Nigeria"

import excel using "Oolu_survey_20210329.xlsx", clear first allstring

drop if call_info!="Customer is available (OK)"

sort customer_id Horodat

drop Horodat 
duplicates drop
drop if customer_name=="ja  vu  t es  message  sur  whatsap  j  ai pas  voulu lire pour  ne  peut"
drop if customer_id=="19062604008" & Adres=="lydia.ataniye@oolusolar.com"

rename customer_id account_number

save oolu_survey, replace

import delimited using "accounts_1615389054_us19632019.csv", delim(",") clear bindquote(strict)

keep account_number group_name initial_group_name status total_amount total_payed last_payment ///
	system_type_name prev_payment date_disabled days_to_cutoff expected_paid number_payment day_disabled ///
	written_off state lga village churn_prediction created_at
	
save temp1, replace

import delimited using "accounts_1615389075_us19632019.csv", delim(",") clear bindquote(strict)

keep account_number group_name initial_group_name status total_amount total_payed last_payment ///
	system_type_name prev_payment date_disabled days_to_cutoff expected_paid number_payment day_disabled ///
	written_off state lga village churn_prediction created_at
	
save temp2, replace

import delimited using "accounts_1615389090_us19632019.csv", delim(",") clear bindquote(strict)

keep account_number group_name initial_group_name status total_amount total_payed last_payment ///
	system_type_name prev_payment date_disabled days_to_cutoff expected_paid number_payment day_disabled ///
	written_off state lga village churn_prediction created_at
	
save temp3, replace

import delimited using "accounts_1615389102_us19632019.csv", delim(",") clear bindquote(strict)

keep account_number group_name initial_group_name status total_amount total_payed last_payment ///
	system_type_name prev_payment date_disabled days_to_cutoff expected_paid number_payment day_disabled ///
	written_off state lga village churn_prediction created_at
	
save temp4, replace

import delimited using "accounts_1615389123_us19632019.csv", delim(",") clear bindquote(strict)

keep account_number group_name initial_group_name status total_amount total_payed last_payment ///
	system_type_name prev_payment date_disabled days_to_cutoff expected_paid number_payment day_disabled ///
	written_off state lga village churn_prediction created_at
	
save temp5, replace

import delimited using "accounts_1615389143_us19632019.csv", delim(",") clear bindquote(strict)

keep account_number group_name initial_group_name status total_amount total_payed last_payment ///
	system_type_name prev_payment date_disabled days_to_cutoff expected_paid number_payment day_disabled ///
	written_off state lga village churn_prediction created_at
	
append using temp1 temp2 temp3 temp4 temp5 

save oolu_nigeria_accounts_20210310, replace

g sale_2018 = strpos(created_at,"2018")>0
g sale_2019 = strpos(created_at,"2019")>0
g sale_2020 = strpos(created_at,"2020")>0
g sale_2021 = strpos(created_at,"2021")>0

tab sale_2020 if inlist(state,"LAGOS","OGUN","ONDO","OSUN","OYO")

tab group_name if inlist(state,"LAGOS","OGUN","ONDO","OSUN","OYO") & sale_2020

g monthly = strpos(group_name,"Monthly")>0
replace monthly = 1 if strpos(group_name,"7500/3750")>0

tab monthly if sale_2020 & inlist(state,"LAGOS","OGUN","ONDO","OSUN","OYO")

* Oolu customer survey stats
merge m:1 account_number using oolu_survey
keep if _m==3

tab save_generator_bills
tab save_power_bills
tab air_quality

split generator_hours_before, parse(":") generate(hours_before)
split generator_hours_after, parse(":") generate(hours_after)

destring hours_before* hours_after*, replace

replace hours_before1 = 0 if missing(hours_before1)
replace hours_after1 = 0 if missing(hours_after1)
g hours_diff = hours_after1 - hours_before1
sum hours_diff, detail

destring fuel_costs*, replace force
replace fuel_costs_before = 0 if missing(fuel_costs_before)
replace fuel_costs_after = 0 if missing(fuel_costs_after)
g fuel_costs_diff = fuel_costs_after - fuel_costs_before 
sum fuel_costs_diff, detail